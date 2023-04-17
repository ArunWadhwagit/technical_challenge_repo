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
#Create an internal load balancer
resource "azurerm_lb" "app_lb" {
 name                = "app_lb"
 location            = var.location
 resource_group_name = var.resource_group
 sku = "Standard"

 frontend_ip_configuration {
   name                 = "InternalIPAddress"
   subnet_id            = var.app_subnet_id
 }
}
#Create a backend pool
resource "azurerm_lb_backend_address_pool" "app_bpepool" {
 
 loadbalancer_id     = azurerm_lb.app_lb.id
 name                = "BackEndAddressPool"
}
#Create load balancer probe
resource "azurerm_lb_probe" "app_probe" {
 loadbalancer_id     = azurerm_lb.app_lb.id
 name                = "zantac-running-probe"
 port                = 80
}
#Create load balancer rule
resource "azurerm_lb_rule" "app_lb_rule" {
   loadbalancer_id                = azurerm_lb.app_lb.id
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = 80
   backend_port                   = 80
   backend_address_pool_ids        = [azurerm_lb_backend_address_pool.app_bpepool.id]
   frontend_ip_configuration_name = "InternalIPAddress"
   probe_id                       = azurerm_lb_probe.app_probe.id
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

