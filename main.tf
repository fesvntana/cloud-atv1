terraform {
  required_version = ">= 0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.55.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource-group-tf" {
  name     = "resource-group-tf"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet-terraform-cloud" {
  name                = "vnet-terraform-cloud"
  location            = azurerm_resource_group.resource-group-tf.location
  resource_group_name = azurerm_resource_group.resource-group-tf.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "subnet-terraform" {
  name                 = "subnet-terraform"
  resource_group_name  = azurerm_resource_group.resource-group-tf.name
  virtual_network_name = azurerm_virtual_network.vnet-terraform-cloud.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public-ip-terraform" {
  name                = "public-ip-terraform"
  resource_group_name = azurerm_resource_group.resource-group-tf.name
  location            = azurerm_resource_group.resource-group-tf.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
    disciplina = "Cloud Automation"
  }
}

resource "azurerm_network_interface" "net-interface-terraform" {
  name                = "net-interface-terraform"
  location            = azurerm_resource_group.resource-group-tf.location
  resource_group_name = azurerm_resource_group.resource-group-tf.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-terraform.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip-terraform.id
  }
}

resource "azurerm_network_security_group" "net-security-tf" {
  name                = "net-security-tf"
  location            = azurerm_resource_group.resource-group-tf.location
  resource_group_name = azurerm_resource_group.resource-group-tf.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "net-int-security-assoc" {
  network_interface_id      = azurerm_network_interface.net-interface-terraform.id
  network_security_group_id = azurerm_network_security_group.net-security-tf.id
}

resource "azurerm_linux_virtual_machine" "vm-terraform" {
  name                            = "vm-terraform"
  resource_group_name             = azurerm_resource_group.resource-group-tf.name
  location                        = azurerm_resource_group.resource-group-tf.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "adminuser"
  admin_password                  = "Admin@123!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.net-interface-terraform.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "null_resource" "install-nginx" {
  connection {
    type     = "ssh"
    host     = azurerm_public_ip.public-ip-terraform.ip_address
    user     = "adminuser"
    password = "Admin@123!"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install -y nginx"]
  }

  depends_on = [azurerm_linux_virtual_machine.vm-terraform]
}