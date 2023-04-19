#Create Availability set for web tier
resource "azurerm_availability_set" "web_availabilty_set" {
  name                = "web_availabilty_set"
  location            = var.location
  resource_group_name = var.resource_group
}
#Create public ip for vmss
resource "azurerm_public_ip" "web_vmss_pip" {
 name                         = var.web_vmss_pip
 location                     = var.location
 resource_group_name          = var.resource_group
 allocation_method = "Static"
 sku = "Standard"
}
#Create a load balancer
resource "azurerm_lb" "web_lb" {
 name                = var.lb_name
 location            = var.location
 resource_group_name = var.resource_group
 sku = "Standard"

 frontend_ip_configuration {
   name                 = "PublicIPAddress"
   public_ip_address_id = azurerm_public_ip.web_vmss_pip.id
 }
}
#Create a backend pool
resource "azurerm_lb_backend_address_pool" "bpepool" {
 
 loadbalancer_id     = azurerm_lb.web_lb.id
 name                = "BackEndAddressPool"
}
#Create load balancer probe
resource "azurerm_lb_probe" "web_probe" {
 loadbalancer_id     = azurerm_lb.web_lb.id
 name                = "zantac-running-probe"
 port                = 80
}
#Create load balancer rule
resource "azurerm_lb_rule" "web_lb_rule" {
   loadbalancer_id                = azurerm_lb.web_lb.id
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = 80
   backend_port                   = 80
   backend_address_pool_ids        = [azurerm_lb_backend_address_pool.bpepool.id]
   frontend_ip_configuration_name = "PublicIPAddress"
   probe_id                       = azurerm_lb_probe.web_probe.id
}
#Create a virtual machine scale set
resource "azurerm_virtual_machine_scale_set" "web_vmss" {
 name                = "var.web_vmss"
 location            = var.location
 resource_group_name = var.resource_group
 upgrade_policy_mode = "Manual"
 availability_set_id = azurerm_availability_set.web_availabilty_set.id
 sku {
   name     = "Standard_B1S"
   tier     = "Standard"
   capacity = 2
 }
 tags = {
  tag_group_vmss = "my-vmss-group"
 }

 storage_profile_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_profile_os_disk {
   name              = ""
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 10
 }

 os_profile {
   computer_name_prefix = "vmlab"
   admin_username       = "arwadhwa"
   custom_data          = file("web.conf")
 }

 os_profile_linux_config {
   disable_password_authentication = true
   ssh_keys {
      path     = "/home/arwadhwa/.ssh/authorized_keys"
      key_data = file("C:/Users/DELL/Desktop/publicis_Exercise/web_server_tf_code/mykey.pem.pub")
    }
  }
 network_profile {
   name    = "terraformnetworkprofile"
   primary = true
   network_security_group_id = var.web_nsg_id

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = var.web_subnet_id
     load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
     primary = true
   }
 }
}
#Create  an autoscale setting
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${var.zantac}-autoscale"
  resource_group_name = var.resource_group
  location            = var.location
  target_resource_id  = azurerm_virtual_machine_scale_set.web_vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id =  azurerm_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["arun.wadhwa88@gmail.com"]
    }
  }
}
#Create Availability set for app tier
resource "azurerm_availability_set" "app_availabilty_set" {
  name                = "app_availabilty_set"
  location            = var.location
  resource_group_name = var.resource_group
 }
#Create an app gateway
resource "azurerm_application_gateway" "app_gateway" {
  name                = "app-gateway"
  location            = var.location
  resource_group_name = var.resource_group
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name      = "app-gateway-ip-config"
    subnet_id = var.app_subnet_id
  }
  frontend_port {
    name = "app-gateway-port"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "app-gateway-ip-config"
    public_ip_address_id = var.public_ip_address_id
  }
  backend_address_pool {
    name = "app-gateway-backend-pool"
    backend_address {
      fqdn = azurerm_virtual_machine_scale_set.app_vmss.load_balancer_backend_address_pool_ids[0]
    }
  }
  backend_http_settings {
    name                  = "app-gateway-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
  }
  http_listener {
    name                           = "app-gateway-http-listener"
    frontend_ip_configuration_name = "app-gateway-ip-config"
    frontend_port_name             = "app-gateway-port"
    protocol                       = "Http"
  }
  request_routing_rule {
    name                       = "app-gateway-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "app-gateway-http-listener"
    backend_address_pool_name  = "app-gateway-backend-pool"
    backend_http_settings_name = "app-gateway-http-settings"
  }
}

#Create a virtual machine scale set
resource "azurerm_virtual_machine_scale_set" "app_vmss" {
 name                = "var.app_vmss"
 location            = var.location
 resource_group_name = var.resource_group
 upgrade_policy_mode = "Manual"
 availability_set_id = azurerm_availability_set.app_availabilty_set.id
 sku {
   name     = "Standard_B1S"
   tier     = "Standard"
   capacity = 2
 }
 tags = {
  tag_group_vmss = "my-vmss-group"
 }

 storage_profile_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_profile_os_disk {
   name              = ""
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 10
 }

 os_profile {
   computer_name_prefix = "vmapp"
   admin_username       = "arwadhwa"
 }

 os_profile_linux_config {
   disable_password_authentication = true
   ssh_keys {
      path     = "/home/arwadhwa/.ssh/authorized_keys"
      key_data = file("C:/Users/DELL/Desktop/publicis_Exercise/web_server_tf_code/mykey.pem.pub")
    }
  }
 network_profile {
   name    = "terraformnetworkprofile"
   primary = true
   network_security_group_id = var.web_nsg_id

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = var.app_subnet_id
     load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
     application_gateway_backend_address_pool_ids = [azurerm_application_gateway.app_gateway.backend_address_pool_id]
     primary = true
   }
 }
}
#Create  an autoscale setting
resource "azurerm_monitor_autoscale_setting" "app_vmss" {
  name                = "var.app_vmss"
  resource_group_name = var.resource_group
  location            = var.location
  target_resource_id  = azurerm_virtual_machine_scale_set.app_vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.app_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id =  azurerm_virtual_machine_scale_set.app_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["arun.wadhwa88@gmail.com"]
    }
  }
}

