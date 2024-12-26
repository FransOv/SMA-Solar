class SmaMb
#Environment
static var inverter="192.168.2.128" # test-value is "192.168.2.124"  !!!!!!!!!!!!!!!!!!!!!!!!
static var baseTopic="sma_solar/"    # test value is ="sma_test/"    !!!!!!!!!!!!!!!!!!!!!!!!
static var chargereg=40795      # Charge limit: 40795 or 44433
static var dischargereg=40799   # Discharge limit: 40799 or 44437
#
# the way to set charge/discharge via ModBus for 30 minutes:
# register 40151 / 44427 to enable 802 or disable 803 charge/discharge control via ModBus
# register 40149 / 44425 charge (-) or discharge (+) power 
#

#ModBus constants
static var readInputRegs=4
static var readHoldingRegs=3
static var writeHoldingRegs=16
static var modBusError =["None","Illegal function","Illegal address","Illegal data value","Server failure","Ack wait","Nack","Server busy","Parity error","Timeout","Gateway unavailable","Gateway no response","12","13","14","15","No connection","17","18","19","20"]

#Requests 
var pollItems # list of [name,address,length,scale,unit,value]
var maps      # map with keyvalue: text
var commands    # list of [function, address, length, data]
var command

#Control variables
var dp
var requestOutstanding
var stdDelay
var stopqry
var delay

#Energy variables
var wallbox
var pva
var pvb
var batteryEnergy
var batteryPower
var charge
var discharge

def init()
 import mqtt
 self.pollItems=[
  ["inverter_status", 32385, 2, 1, "x",""],
  ["operating_status", 40029, 2, 1, "x",""],
  ["ac_daily_yield", 30535, 2, 1, "Wh",0],
  ["ac_total_yield", 30531, 2, 1, "kWh",0],
  ["dc_current_a", 30769, 2, 0.001, "A",0],
  ["dc_voltage_a", 30771, 2, 0.01, "V",0],
  ["dc_power_a", 30773, 2, 1, "W",0],
  ["dc_current_b", 30957, 2, 0.001, "A",0],
  ["dc_voltage_b", 30959, 2, 0.01, "V",0],
  ["dc_power_b", 30961, 2, 1, "W",0],
  ["ac_power", 30775, 2, 1, "W",0],
  ["ac_power_l1", 30777, 2, 1, "W",0],
  ["ac_power_l2", 30779, 2, 1, "W",0],
  ["ac_power_l3", 30781, 2, 1, "W",0],
  ["ac_voltage_l1", 30783, 2, 0.01, "V",0],
  ["ac_voltage_l2", 30785, 2, 0.01, "V",0],
  ["ac_voltage_l3", 30787, 2, 0.01, "V",0],
  ["ac_current", 30795, 2, 0.001, "A",0],
  ["ac_current_l1", 30977, 2, 0.001, "A",0],
  ["ac_current_l2", 30979, 2, 0.001, "A",0],
  ["ac_current_l3", 30981, 2, 0.001, "A",0],
  ["battery_status", 31391, 2, 1, "x",0],
  ["battery_state", 30955, 2, 1, "x",0],
  ["battery_charge", 31397, 4, 1, "Wh",0],
  ["battery_charging", 31393, 2, 1, "W",0],
  ["battery_discharging", 31395, 2, 1, "W",0]
 ]
  self.maps={
  "inverter_status":{0:"None",35: "Fault",303: "Off",307: "OK",455:" Warning "},
  "operating_status":{0:"None",303: "Off",569:"Activated",1295: "Standby",1795: "Locked",16777213: "NA"},
  "battery_status":{0:"None",35:"Fault",303:"Off",307:"OK",455:"Warning",16777213:"NA"},
  "battery_state":{0:"None",303:"Off",2291:"Standby",3664:"Emergency_charge",2292:"Charge",2293:"Discharge",16777213:"NA"}
 }
 self.dp=-1
 self.commands=[]
 self.command=false
 self.requestOutstanding=false
 self.stdDelay=0
 self.delay=1
 self.stopqry=false
 
 self.wallbox=0
 self.pva=0
 self.pvb=0
 self.batteryEnergy=0
 self.batteryPower=0
 
 tasmota.remove_cmd("qrystop")
 tasmota.add_cmd("qrystop", /c, i, p, pj -> self.qrystop(c, i, p, pj))
 tasmota.remove_cmd("chargelimit")
 tasmota.add_cmd("chargelimit", /c, i, p, pj -> self.chargelimit(c, i, p, pj))
 tasmota.remove_cmd("dischargelimit")
 tasmota.add_cmd("dischargelimit", /c, i, p, pj -> self.dischargelimit(c, i, p, pj))
 tasmota.remove_cmd("request")
 tasmota.add_cmd("request", /c, i, p, pj -> self.request(c, i, p, pj))

 mqtt.unsubscribe("go-eCharger/205930/tpa")
 mqtt.subscribe("go-eCharger/205930/tpa", /t,idx,ps,pb -> self.wb(t,idx,ps,pb))
 mqtt.publish(self.baseTopic+"LWT","Online",true)
 global.mbtcp.connect(self.inverter,3)
 
 if global.pwr==nil  global.pwr=0 end
end #init

def qrystop(c, i, p, pj)
 self.stopqry= !self.stopqry
 tasmota.resp_cmnd(f'{{"QryStopped":{self.stopqry}}}')
end #qrystop

def chargelimit(c, i, p, pj)
 if p!=""
  self.charge=int(p)
  self.commands.push([self.writeHoldingRegs,self.chargereg,2,bytes().add(self.charge,-4)])
 end
 tasmota.resp_cmnd(f'{{"chargelimit":{self.charge}}}')
end #chargelimit

def dischargelimit(c, i, p, pj)
 if p!=""
  self.discharge=int(p)
  self.commands.push([self.writeHoldingRegs,self.dischargereg,2,bytes().add(self.discharge,-4)])
 end
 tasmota.resp_cmnd(f'{{"dischargelimit":{self.discharge}}}')
end #dischargelimit

def request(c, i, p, pj)
 import string
 if p!=""
  var req=string.split(p,",")
  var data
  if size(req)==4
   data=bytes().add(int(req[3]),-int(req[2])*2)
  end
  self.commands.push([req[0],req[1],req[2],data])
 end
 tasmota.resp_cmnd(f'{{"response":true}}')
end #request


def wb(topic,idx,payload_s,payload_b)
 self.wallbox=real(payload_s)/1000
end #wb

def callback(result,response)
 import mqtt
 import string
 import math
 #print("Result: ",result,"Response: ",response)
 if result && !self.command
  try
   if response==bytes("8000000000000000")[0..size(response)-1] || response==bytes("FFFFFFFFFFFFFFFF")[0..size(response)-1]
    response=bytes("0000000000000000")[0..size(response)-1]
   end
   var value
   if size(response)==8
    value=real(int64().frombytes(response.reverse()).tostring())
   else
    value=response.geti(0,-2*self.pollItems[self.dp][2])
   end
   if value !=0
    value*=self.pollItems[self.dp][3]
   end
   var mvalue=nil
   if self.pollItems[self.dp][4]=="x"
    mvalue=self.maps.find(self.pollItems[self.dp][0])
   end
   if mvalue!=nil
    value=mvalue.find(value)
   else
    value=string.format("%.3f",value)
   end
   #print("MQTT:",self.baseTopic+self.pollItems[self.dp][0],value)
   self.pollItems[self.dp][5]=value
   if self.pollItems[self.dp][0]=="dc_power_a" self.pva=int(value) 
   elif self.pollItems[self.dp][0]=="dc_power_b" self.pvb=int(value) 
   elif self.pollItems[self.dp][0]=="battery_charge" self.batteryEnergy=int(value) 
   elif self.pollItems[self.dp][0]=="battery_charging" self.batteryPower=-int(value) 
   elif self.pollItems[self.dp][0]=="battery_discharging" self.batteryPower=-int(value)
   end
   mqtt.publish(self.baseTopic+self.pollItems[self.dp][0],value)
  except .. as e
   print("Berry error:", e)
  end
 elif result && self.command
  print(self.baseTopic+"response",f"{self.commands[0][0]},{self.commands[0][1]},{self.commands[0][2]},{self.commands[0][3]},{response}")
  #mqtt.publish(self.baseTopic+"response:",f"{self.commands[0][0]},{self.commands[0][1]},{self.commands[0][2]},{self.commands[0][3]},{response}")
  self.commands.pop(0)
 elif !result
  print("ModBus error:",self.modBusError[response[0]])
  if self.command self.commands.pop(0) end
 end
 self.command=false
 self.requestOutstanding=false
end #callback

def every_second()
 import mqtt
 import string
 if self.delay>0
  self.delay-=1
 else
  if !self.requestOutstanding && !self.stopqry
   if size(self.commands)>0
    self.command=true
    self.requestOutstanding=true
    global.mbtcp.request(self.commands[0][0],self.commands[0][1],self.commands[0][2],/r,d -> self.callback(r,d),self.commands[0][3])
   else
    if self.dp<size(self.pollItems)-1 self.dp+=1 else self.dp=0 end
     #print("Request:",self.pollItems[self.dp][1]>40000 ? 3 : 4,self.pollItems[self.dp][1],self.pollItems[self.dp][2])
    self.requestOutstanding=true
    global.mbtcp.request(self.pollItems[self.dp][1]>40000 ? 3 : 4,self.pollItems[self.dp][1],self.pollItems[self.dp][2],/r,d -> self.callback(r,d))
    mqtt.publish("/go-eCharger/205930/ids/set",
     string.format("{\"pGrid\":%i,\"pPv\":%i,\"pAkku\":%i}",
     -global.pwr*1000,self.pva+self.pvb,self.batteryPower)
    )
   end
  end
  self.delay=self.stdDelay
 end
end #every_second

def web_sensor()
 import string
 var pvs=string.format(
  "{s}Grid Power:{m}% 0.3f kW{e}"..
  "{s}Wallbox Power:{m}% 0.3f kW{e}"..
  "{s}PV Yield:{m}% 0.3f kW{e}"..
  "{s}Battery Energy:{m}% 0.3f kWh{e}"..
  "{s}Battery Power:{m}% 0.3f kW{e}",
  global.pwr, self.wallbox, (self.pva+self.pvb)/1000., self.batteryEnergy, self.batteryPower)
 tasmota.web_send(pvs)
end #web_sensor

end

global.smamb=SmaMb()
tasmota.add_driver(global.smamb)
