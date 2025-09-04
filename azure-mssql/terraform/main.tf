# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.project_prefix}-rg"
  location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.project_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a network security group
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.project_prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowFlask"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = var.my_ip_address
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowLocust"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8089"
    source_address_prefix      = var.my_ip_address
    destination_address_prefix = "*"
  }
}

# Create a public IP
resource "azurerm_public_ip" "pip" {
  name                = "${var.project_prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.project_prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Associate NSG to NIC
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create the virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.project_prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3" # Increased size for better Docker performance
  admin_username      = "ubuntu"
  admin_password      = var.admin_password
  disable_password_authentication = false 

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

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

  # cloud-init script for setup
  custom_data = base64encode(templatefile("${var.project_root_path}/app/setup.sh", {
    project_prefix                 = var.project_prefix
    sql_password                   = var.sql_password
    new_relic_license_key          = var.new_relic_license_key
    new_relic_team_tag             = var.new_relic_team_tag
    new_relic_environment_tag      = var.new_relic_environment_tag
    docker_compose_file            = file("${var.project_root_path}/docker-compose.yml")
    app_dockerfile                 = file("${var.project_root_path}/app/Dockerfile")
    app_requirements_file          = file("${var.project_root_path}/app/requirements.txt")
    app_py_file                    = file("${var.project_root_path}/app/app.py")
    app_locustfile_file            = file("${var.project_root_path}/app/locustfile.py")
    app_newrelic_file              = file("${var.project_root_path}/app/newrelic.ini")
    app_index_html_file            = file("${var.project_root_path}/app/templates/index.html")
    mssql_dockerfile               = file("${var.project_root_path}/mssql/Dockerfile")
    mssql_setup_sql_file           = file("${var.project_root_path}/mssql/setup_sql.sh")
    mssql_stored_procedures_file   = file("${var.project_root_path}/mssql/stored_procedures.sql")
  }))

  depends_on = [ azurerm_network_interface_security_group_association.nsg_assoc ]
}

