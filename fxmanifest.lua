fx_version 'cerulean'
games { 'gta5' }

name 'Pulsar Vehicles'
description 'The core vehicle system: spawning, keys, identification, impound, and storage'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.1'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_vehicles'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

client_scripts({
	'@pulsar_polyzone/client.lua',
	'@pulsar_polyzone/BoxZone.lua',
	'@pulsar_polyzone/EntityZone.lua',
	'shared/**/*.lua',
	'client/**/*.lua',
})

server_scripts({
	'shared/**/*.lua',
	'server/**/*.lua',
})

lua54 'yes'