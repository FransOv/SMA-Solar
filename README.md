# SMA-Solar
Tasmota-Berry modules to interface with SMA inverters

All brand specific Home automation managers are a real pain. We have an SMA inverter for the solar panels and the (coming soon) battery, a Viessmann heatpump and a GO-e wallbox. All three offer a home mananger and all of them are closed tightly in their own ecosystem and not able to talk to each other. If I were to implement them I would need three electricity meters/hoem managers in parallel (12 units) in the cabinet of my grid connection, which in a 100+ year old house is clearly impossible. So I have based my home automation on Home Assistant running on a Ubuntu/Intel box and ESP-Tasmota for all my sensors, actuators and bridges (60+ total).
The grid elelctricity meter from the utility company has a P1 port that outputs the relevant measurements. I read this with an Esp running Tasmota with a Berry program and publish the measurements to MQTT (https://github.com/FransOv/p12mqtt). These measurments are use by Home Assistant and by a second Esp that emulates an SMA Energy meter and publishes the information in the SMA required format on Speedwire (UDP-Multicast) so it can be pickedd up by the inverter. On this same esp is a second Berry program that reads the information from the inverter via ModBus/TCP adn publishes the inverter data via MQTT so it can be picked up by Home Assistannt. Also on that esp is a third Berry program that acts as a ModBus/TCP master as the standard Tasmota ModBus/TCP functions can only be used as a bridge between ModBus/RTU and ModBus/TCP.
I use Optolink-Splitter (https://github.com/philippoo66/optolink-splitter/) on a Pi to read the relevant data from the Viesssmann heatpump and to control the heatpump from Home Assistant, also MQTT based. 
This repository contains the Berry programs that form the bridge to the SMA inverter. Read only now as the solar panels don't really need any control, but to be expanded with some cotrolling funcions as soon as the battery is installed.

mbtcp.be => The ModBus/TCP functions

smamb.be => Reading the inverter data via ModBus/TCP

meter.be => Broadcasting the readings from the utility meter via Speedwire  (UDP-Multicast
