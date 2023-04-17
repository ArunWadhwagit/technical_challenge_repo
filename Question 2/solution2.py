import json
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import InstanceViewStatus

# Define your Azure subscription ID and resource group name
subscription_id = 'your_subscription_id'
resource_group_name = 'your_resource_group_name'

# Define the name of the virtual machine instance you want to query
vm_name = 'your_vm_name'

# Initialize the Azure credentials
credential = DefaultAzureCredential()

# Initialize the ComputeManagementClient with your credentials and subscription ID
compute_client = ComputeManagementClient(credential, subscription_id)

# Retrieve the instance data for the virtual machine instance
vm_instance = compute_client.virtual_machines.get(resource_group_name, vm_name, expand='instanceView')

# Get the instanceView from the vm_instance
instance_view = vm_instance.instance_view

# Initialize an empty dictionary to store the metadata
metadata_dict = {}

# Loop through each status in the instanceView and add the metadata to the dictionary
for status in instance_view.statuses:
    if status.code.startswith('PowerState'):
        metadata_dict['power_state'] = status.display_status
    elif status.code.startswith('ProvisioningState'):
        metadata_dict['provisioning_state'] = status.display_status
    elif status.code.startswith('VmAgent'):
        metadata_dict['vm_agent'] = status.display_status

# Convert the metadata dictionary to JSON format
metadata_json = json.dumps(metadata_dict)

# Print the metadata JSON
print(metadata_json)

power_state = metadata_dict['power_state']
print(power_state)
