# SMA-Solar
Tasmota-Berry modules to interface with SMA inverters

All brand specific Home automation managers are a real pain. We have an SMA inverter for the solar panels and the battery, a Viessmann heatpump and a GO-e wallbox. All three offer a home mananger and all of them are closed tightly in their own ecosystem and not able to talk to each other. If I were to implement them I would need three electricity meters/home managers in parallel (12 units) in the cabinet of my grid connection, which in a 100+ year old house is clearly impossible. So I have based my home automation on Home Assistant running on a Ubuntu/Intel box and ESP-Tasmota for all my sensors, actuators and bridges (60+ total).

The grid electricity meter from the utility company has a P1 port that outputs the relevant measurements. I read this with an Esp running Tasmota with a Berry program and publish the measurements to MQTT (https://github.com/FransOv/p12mqtt). These measurments are used by Home Assistant and by a second Esp that emulates an SMA Energy meter and publishes the information in the SMA required format on Speedwire (UDP-Multicast) so it can be pickedd up by the inverter. On this same esp is a second Berry program that reads the information from the inverter via ModBus/TCP and publishes the inverter data via MQTT so it can be picked up by Home Assistannt. Also on that esp is a third Berry program that acts as a ModBus/TCP master as the standard Tasmota ModBus/TCP functions can only be used as a bridge between ModBus/RTU and ModBus/TCP.

I use Optolink-Splitter (https://github.com/philippoo66/optolink-splitter/) on a Pi to read the relevant data from the Viesssmann heatpump and to control the heatpump from Home Assistant, also MQTT based. For the Go-e wallbox I use their own mqtt based integration. No need to install, the wallbox sends its discovery messages when you enable Home Assistant in the Go-e app.

This repository contains the Berry programs that form the bridge to the SMA inverter. It reads the sensors of the inverter and passes the commands to control charging and discharging os the battery. Most of the time charging and discharging is left on automatic. I recently switched to the Home Assistant SMA integration (https://www.home-assistant.io/integrations/sma/) for reading the sensors as I could not get all info via ModBus and also because the inverter doesn't seem to like frequent (1 to 2 seconds interval) queries via ModBus. I still use ModBus to send commands to the inverter.

mbtcp.be => The ModBus/TCP functions

smamb.be => Reading the inverter data via ModBus/TCP (and also providing the Go-e wallbox with information about grid, solar panels and battery)

meter.be => Broadcasting the readings from the utility meter via Speedwire  (UDP-Multicast)
