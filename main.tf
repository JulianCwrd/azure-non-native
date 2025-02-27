provider "azurerm" {
  subscription_id = "1df50e13-c052-4ceb-a066-d62f1f368fe4"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group (NSG) - Allows SSH & MySQL
resource "azurerm_network_security_group" "example" {
  name                = "example-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowMySQL"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.example.id
}

# Create a Public IP Address 
resource "azurerm_public_ip" "example" {
  name                = "example-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"  # Standard SKU requires Static allocation
  sku                 = "Standard"
}

# Network Interface (NIC) with Public IP
resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id  # Attach Public IP
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Ensure Terraform waits for Public IP assignment before running SSH
  depends_on = [azurerm_public_ip.example]
}

# Output Public IP for Easy Access
output "vm_public_ip" {
  value       = azurerm_public_ip.example.ip_address
  description = "Public IP address of the VM"
}


resource "azurerm_policy_definition" "mysql_policy" {
  name         = "Ensure-MySQL-Installed"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Ensure MySQL is Installed on VMs"
  
  metadata = <<METADATA
  {
    "category": "Compute"
  }
  METADATA

  policy_rule = <<POLICY_RULE
  {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Compute/virtualMachines"
        }
      ]
    },
    "then": {
      "effect": "DeployIfNotExists",
      "details": {
        "type": "Microsoft.Compute/virtualMachines/extensions",
        "name": "install-mysql",
        "existenceCondition": {
          "field": "name",
          "equals": "install-mysql"
        },
        "roleDefinitionIds": [
          "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        ],
        "deployment": {
          "properties": {
            "mode": "incremental",
            "parameters": {
              "vmName": {
                "value": "[field('name')]"
              },
              "location": {
                "value": "[field('location')]"
              }
            },
            "template": {
              "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
              "contentVersion": "1.0.0.0",
              "parameters": {
                "vmName": {
                  "type": "string"
                },
                "location": {
                  "type": "string"
                }
              },
              "resources": [
                {
                  "type": "Microsoft.Compute/virtualMachines/extensions",
                  "apiVersion": "2021-03-01",
                  "name": "[concat(parameters('vmName'), '/install-mysql')]",
                  "location": "[parameters('location')]",
                  "properties": {
                    "publisher": "Microsoft.Azure.Extensions",
                    "type": "CustomScript",
                    "typeHandlerVersion": "2.0",
                    "autoUpgradeMinorVersion": true,
                    "settings": {
                      "fileUris": ["https://raw.githubusercontent.com/JulianCwrd/azure-non-native/refs/heads/main/install-mysql.sh"],
                      "commandToExecute": "bash install-mysql.sh"
                    }
                  }
                }
              ]
            }
          }
        }
      }
    }
  }
  POLICY_RULE
}


# Assign Policy to the Resource Group
resource "azurerm_resource_group_policy_assignment" "mysql_policy_assignment" {
  name  = "mysql-policy-assignment"
  resource_group_id    = azurerm_resource_group.example.id
  policy_definition_id = azurerm_policy_definition.mysql_policy.id
  location             = azurerm_resource_group.example.location

  identity {
    type = "SystemAssigned"
  }
}