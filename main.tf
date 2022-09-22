terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources"
  location = "East Asia"
  tags = {
    environment = "dev"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }

}

# resource "azurerm_subnet" "mtc-subnet" {
#   for_each = var.subnets
#   name                 = each.value["name"]
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = each.value["address_prefixes"]
# }

resource "azurerm_subnet" "mtc-subnet1" {
  name                 = "mtc-subnet1"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

# resource "azurerm_subnet" "mtc-subnet2" {
#   name                 = "mtc-subnet2"
#   resource_group_name  = azurerm_resource_group.mtc-rg.name
#   virtual_network_name = azurerm_virtual_network.mtc-vn.name
#   address_prefixes     = ["10.123.2.0/24"]
# }

resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga1" {
  subnet_id                 = azurerm_subnet.mtc-subnet1.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}

# resource "azurerm_subnet_network_security_group_association" "mtc-sga2" {
#   subnet_id                 = azurerm_subnet.mtc-subnet2.id
#   network_security_group_id = azurerm_network_security_group.mtc-sg.id
# }

resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_availability_set" "mtc-availset" {
  name                        = "mtc-availset"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  location                    = azurerm_resource_group.mtc-rg.location
  platform_fault_domain_count = 2

  tags = {
    environment = "dev"
  }

}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet1.id
    private_ip_address_allocation = "Dynamic"
    //public_ip_address_id          = azurerm_public_ip.mtc-ip1.id

  }

  tags = {
    environment = "dev"
  }

}

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id,
  ]

  availability_set_id = azurerm_availability_set.mtc-availset.id

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/mtcazurekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "mtc-nic2" {
  name                = "mtc-nic2"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet1.id
    private_ip_address_allocation = "Dynamic"
    //public_ip_address_id          = azurerm_public_ip.mtc-ip2.id

  }

  tags = {
    environment = "dev"
  }

}

resource "azurerm_linux_virtual_machine" "mtc-vm2" {
  name                = "mtc-vm2"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic2.id,
  ]

  availability_set_id = azurerm_availability_set.mtc-availset.id

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/mtcazurekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_lb" "mtc-lb" {
  name                = "mtc-lb"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.mtc-ip.id
  }

}


resource "azurerm_lb_backend_address_pool" "mtc-bp" {
  loadbalancer_id = azurerm_lb.mtc-lb.id
  name            = "mtc-bp"
  depends_on = [
    azurerm_lb.mtc-lb,
    azurerm_availability_set.mtc-availset
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "mtc-bp-asso1" {
  network_interface_id    = azurerm_network_interface.mtc-nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.mtc-bp.id
}

resource "azurerm_network_interface_backend_address_pool_association" "mtc-bp-asso2" {
  network_interface_id    = azurerm_network_interface.mtc-nic2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.mtc-bp.id
}

resource "azurerm_lb_probe" "mtc-lbp" {
  loadbalancer_id = azurerm_lb.mtc-lb.id
  name            = "mtc-lbp"
  port            = 5000
  depends_on = [
    azurerm_lb.mtc-lb
  ]
}

resource "azurerm_lb_rule" "mtc-lbrule" {
  loadbalancer_id = azurerm_lb.mtc-lb.id
  //resource_group_name = azurerm_resource_group.mtc-rg.name
  name                           = "mtc-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 5000
  backend_port                   = 5000
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.mtc-bp.id]
  probe_id                       = azurerm_lb_probe.mtc-lbp.id
  depends_on = [
    azurerm_lb.mtc-lb,
    azurerm_availability_set.mtc-availset,
    azurerm_lb_probe.mtc-lbp

  ]
}

data "azurerm_public_ip" "mtc-ip-data" {
  name                = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.mtc-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}