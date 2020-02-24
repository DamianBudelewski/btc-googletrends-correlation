variable "shinyapp" {
    type = map
    default = {
        "rg_name"		= "shinyapp-rg"
        "location"		= "westeurope"
        "admin_username"	= "admin"
        "fqdn"			= "nycvisshinyapp"
	"azure_fqdn"		= "nycvisshinyapp.westeurope.cloudapp.azure.com"
    }
}
