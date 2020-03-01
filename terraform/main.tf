provider "azurerm" {
  version = "= 1.33.0"
}

# Create a resource group if it doesnt exist
resource "azurerm_resource_group" "resourcegroup" {
    name     = var.bitcoingtrends["rg_name"]
    location = var.bitcoingtrends["location"]
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
    name                = "virtual-network"
    address_space       = ["10.0.0.0/16"]
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
}

# Create subnet. Define creating vnet before subnet by refering network name in subnet definition
resource "azurerm_subnet" "subnet" {
    name                 = "subnet"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
    name		= "publicip"
    allocation_method	= "Dynamic"
    domain_name_label	= var.bitcoingtrends["fqdn"]
    resource_group_name	= azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "networksecurity" {
    name		= "nsg"
    resource_group_name	= azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
    
    security_rule {
        name                       = "SSH"
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
        name                       = "HTTP"
        priority                   = 999
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
    name			= "nic"
    resource_group_name		= azurerm_resource_group.resourcegroup.name
    location			= azurerm_resource_group.resourcegroup.location
    network_security_group_id	= azurerm_network_security_group.networksecurity.id

    ip_configuration {
        name				= "nic-config"
        subnet_id			= azurerm_subnet.subnet.id
        private_ip_address_allocation	= "Dynamic"
        public_ip_address_id		= azurerm_public_ip.publicip.id
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resourcegroup.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name		= azurerm_resource_group.resourcegroup.name
    location			= azurerm_resource_group.resourcegroup.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
    name 				= "vm"
    resource_group_name			= azurerm_resource_group.resourcegroup.name
    location 				= azurerm_resource_group.resourcegroup.location
    network_interface_ids		= [azurerm_network_interface.nic.id]
    delete_os_disk_on_termination 	= true
    delete_data_disks_on_termination 	= true
    vm_size 				= "Standard_B1ms"

    storage_os_disk {
        name              = "osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "btcgtrends"
    	admin_username = "dbudelewski"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            key_data	= file("~/.ssh/id_rsa.pub")
            path	= "/home/dbudelewski/.ssh/authorized_keys"
        }
    }

    boot_diagnostics {
        enabled		= "true"
        storage_uri	= azurerm_storage_account.storageaccount.primary_blob_endpoint
    }
}
