provider "azurerm" {
  features {}
  version = "=2.0.0"
  #subscription_id      = "00000000-0000-0000-0000-000000000000"
  #tenant_id            = "00000000-0000-0000-0000-000000000000"
  skip_provider_registration = true
}

variable "rsgname" {
  description = "Enter Resource group name here"
}

variable "lname" {
  description = "Enter Location here(eg: East US)"
}

#Create storage account
resource "azurerm_storage_account" "sa" {
    name                     = "tfst"    #Enter storage account name here / varable call for the same
    resource_group_name      = var.rsgname      #Enter storage account resourse group name here / varable call for the same
    location                 = var.lname               #Enter region here
    account_tier             = "Standard"
    account_replication_type = "GRS"
   tags = {
    environment = "Terraform Storage"                 #Enter tags here
    CreatedBy = "Admin"
      }
}

# Create virtual network
resource "azurerm_virtual_network" "TFvnet" {
    name                = "TFVnet"                    #Enter Virtual network name here / varable call for the same
    address_space       = ["10.0.0.0/16"]               #Enter address space here
    location            = var.lname                    #Enter region here
    resource_group_name = var.rsgname           #Enter Resource group of Virtual network here / varable call for the same

    tags = {
        environment = "Terraform VNET"                #Enter tags here
    }
}

# Create subnet
resource "azurerm_subnet" "internal" { 
    name                 = "TFSubnet"                 #Enter Subnet name here / varable call for the same
    resource_group_name = var.rsgname           #Enter Resource group of subnet here / varable call for the same
    virtual_network_name = azurerm_virtual_network.TFvnet.name
    address_prefix       = "10.0.1.0/24"
}

#Create security group
resource "azurerm_network_security_group" "nsg" {
  name                = "NSG"                         #Enter Security group name here / varable call for the same
  location            = var.lname                     #Enter region here
  resource_group_name = var.rsgname             #Enter Resource group of Security Group here / varable call for the same
}

#Create rules using security group
resource "azurerm_network_security_rule" "nsgrule1" {
  name                        = "HTTP"               #Enter Security group name here / varable call for the same
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rsgname     #Enter Resource group of Security Group here / varable call for the same
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "nsgrule2" {
  name                        = "HTTPS"             #Enter Security group name here / varable call for the same
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rsgname     #Enter Resource group of Security Group here / varable call for the same
  network_security_group_name = azurerm_network_security_group.nsg.name
}

  resource "azurerm_network_security_rule" "nsgrule3" {
  name                        = "SSH"                 #Enter Security group name here / varable call for the same
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rsgname     #Enter Resource group of Security Group here / varable call for the same
  network_security_group_name = azurerm_network_security_group.nsg.name
}

  resource "azurerm_network_security_rule" "nsgrule4" {
  name                        = "Web80Out"            #Enter Security group name here / varable call for the same
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "80"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.rsgname     #Enter Resource group of Security Group here / varable call for the same
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "subnetnsgassign" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "tfloadbalancerpip" {
  name                = "PublicIPForLB"
  location            = var.lname
  resource_group_name = var.rsgname
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "tfloadbalancer" {
  name                = "TFLoadBalancer"
  location            = var.lname
  resource_group_name = var.rsgname
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.tfloadbalancerpip.id
  }
}


resource "azurerm_lb_backend_address_pool" "lbaddrpool" {
  resource_group_name = var.rsgname
  loadbalancer_id     = azurerm_lb.tfloadbalancer.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = var.rsgname
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.tfloadbalancer.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}
resource "azurerm_lb_probe" "lbprobe" {
  resource_group_name = var.rsgname
  loadbalancer_id     = azurerm_lb.tfloadbalancer.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_lb_rule" "lbrule" {
  resource_group_name            = var.rsgname
  loadbalancer_id                = azurerm_lb.tfloadbalancer.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbaddrpool.id
  probe_id                       = azurerm_lb_probe.lbprobe.id
}

resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                            = "tf-vmss"
  resource_group_name             = var.rsgname
  location                        = var.lname

  sku                             = "Standard_F2"
  instances                       = 3
  
  computer_name_prefix   = "testvm"
  admin_username         = "adminuser"
  admin_password         = "P@ssw0rd1234!"
  custom_data            = filebase64("azure-user-data.sh")

  disable_password_authentication = false


  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.internal.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbaddrpool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lbnatpool.id]
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-config"
  resource_group_name = var.rsgname
  location            = var.lname
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  profile {
    name = "AutoScale"

    capacity {
      default = 3
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU scale up"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
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
        metric_name        = "Percentage CPU scale down"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
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
}


resource "azurerm_mysql_server" "mysqlserver" {
  name                = "mysql-terraformserver-1"
  location            = var.lname
  resource_group_name = var.rsgname


  sku_name   = "B_Gen5_2"

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "mysqladminun"
  administrator_login_password = "easytologin4once!"
  version                      = "5.7"
  ssl_enforcement              = "Enabled"
}

resource "azurerm_mysql_database" "mysqldatabase" {
  name                = "exampledb"
  resource_group_name = var.rsgname
  server_name         = azurerm_mysql_server.mysqlserver.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

#terraform {
#  required_version = ">= 0.12"
    # To store state file in Storage
    # Authenticating using the Azure CLI or a Service Principal (either with a Client Certificate or a Client Secret)
#  backend "azurerm" {
#    resource_group_name  = var.rsgname          
#    storage_account_name = "storage4terraform"        
#    container_name       = "statefile"
#    key                  = "terraform.tfstate"
#  }
#}
