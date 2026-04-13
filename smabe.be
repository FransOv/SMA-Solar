class SmaMb
#Environment
static var inverter="192.168.2.128" # test-value is "192.168.2.124"  !!!!!!!!!!!!!!!!!!!!!!!!
static var baseTopic="sma_solar/"    # test value is ="sma_test/"    !!!!!!!!!!!!!!!!!!!!!!!!
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

def init()
 import mqtt
 self.pollItems=[
#  ["inverter_status", 32385, 2, 1, "x","",0],
#  ["operating_status", 40029, 2, 1, "x","",0],
#  ["ac_daily_yield", 30535, 2, 1, "Wh",0,0],
#  ["ac_total_yield", 30513, 4, 1, "Wh",0,1],
#  ["dc_current_a", 30769, 2, 0.001, "A",0,0],
#  ["dc_voltage_a", 30771, 2, 0.01, "V",0,0],
#  ["dc_power_a", 30773, 2, 1, "W",0,0],
#  ["dc_current_b", 30957, 2, 0.001, "A",0,0],
#  ["dc_voltage_b", 30959, 2, 0.01, "V",0,0],
#  ["dc_power_b", 30961, 2, 1, "W",0,0],
#  ["ac_power", 30775, 2, 1, "W",0,0],
#  ["ac_power_l1", 30777, 2, 1, "W",0,0],
#  ["ac_power_l2", 30779, 2, 1, "W",0,0],
#  ["ac_power_l3", 30781, 2, 1, "W",0,0],
#  ["ac_voltage_l1", 30783, 2, 0.01, "V",0,0],
#  ["ac_voltage_l2", 30785, 2, 0.01, "V",0,0],
#  ["ac_voltage_l3", 30787, 2, 0.01, "V",0,0],
#  ["ac_current", 30795, 2, 0.001, "A",0,0],
#  ["ac_current_l1", 30977, 2, 0.001, "A",0,0],
#  ["ac_current_l2", 30979, 2, 0.001, "A",0,0],
#  ["ac_current_l3", 30981, 2, 0.001, "A",0,0],
#  ["battery_status", 31391, 2, 1, "x",0,0],
#  ["battery_state", 30955, 2, 1, "x",0,0],
#  ["battery_state_of_charge", 30845, 2, 1, "%",0,0],
#  ["battery_application_state", 31057, 2, 1, "x",0,0],
#  ["battery_charge", 31397, 4, 1, "Wh",0,1],
#  ["battery_discharge", 31401, 4, 1, "Wh",0,1],
#  ["battery_charging", 31393, 2, 1, "W",0,0],
#  ["battery_discharging", 31395, 2, 1, "W",0,0],
#  ["battery_current", 30843, 2, 0.001, "A",0,0]
 ]
  self.maps={
  "inverter_status":{0:"None",35: "Fault",303: "Off",307: "OK",455:" Warning "},
  "operating_status":{0:"None",303: "Off",569:"Activated",1295: "Standby",1795: "Locked",16777213: "NA"},
  "battery_status":{0:"None",35:"Fault",303:"Off",307:"OK",455:"Warning",16777213:"NA"},
  "battery_state":{0:"None",303:"Off",2291:"Standby",3664:"Emergency_charge",2292:"Charge",2293:"Discharge",16777213:"NA"},
  "battery_application_state":{2614:"Self-consumption",2615:"SoC conservation",2616:"Backup power",2617:"Deep discharge protection ",2618:"Deep discharge",16777213:"NA"}
 }
 #
 # Solar Total Yield and Solar Power cannot be read by ModBus, using a webquery in HomeAssistant instead: https://inverter/dyn/getDashValues.json 
 #
 self.dp=-1
 self.commands=[]
 self.command=false
 self.requestOutstanding=false
 self.stdDelay=0
 self.delay=0
 self.stopqry=false
 
 tasmota.remove_cmd("qrystop")
 tasmota.add_cmd("qrystop", /c, i, p, pj -> self.qrystop(c, i, p, pj))
 tasmota.remove_cmd("request")
 tasmota.add_cmd("request", /c, i, p, pj -> self.request(c, i, p, pj))

 mqtt.unsubscribe(self.baseTopic+"request")
 mqtt.subscribe(self.baseTopic+"request", /t,idx,ps,pb -> self.request(t,idx,ps,pb))
 mqtt.publish(self.baseTopic+"LWT","Online",true)
 mqtt.publish(self.baseTopic+"request","",false)
 mqtt.publish(self.baseTopic+"response","",false)
 #global.mbtcp.connect(self.inverter,3)
 
 if global.pwr==nil  global.pwr=0 end
end #init

def qrystop(c, i, p, pj)
 self.stopqry= !self.stopqry
 tasmota.resp_cmnd(f'{{"QryStopped":{self.stopqry}}}')
end #qrystop

def request(c, i, p, pj)
 import string
 if !global.mbtcp.tcp.connected()
  global.mbtcp.connect(self.inverter,3)
 end
 if p!=""
  var req=string.split(p,",")
  var data
  if size(req)==4
   data=int64.fromstring(req[3]).tobytes()[0..int(req[2])*2-1].reverse()
  end
  self.commands.push([req[0],req[1],req[2],data])
 end
 tasmota.resp_cmnd(f'{{"response":true}}')
end #request

def mqttreq(topic,idx,payload_s,payload_b)
 self.request(topic,idx,payload_s,nil)
end #mqttreq


def bytes2real(bb)
 if classname(bb)=="bytes"
  var s=size(bb)
  var value
  if s==8
   value=real(int64().frombytes(bb.reverse()).tostring())
  elif s<=4
   value=real(bb.geti(0,-s))
  else
   value=0
  end
  return value
 else
  return bb
 end
end #bytes2real


def callback(result,response)
 import mqtt
 import string
 import math
 global.mbtcp.close()
 try
  #print(result,response)
  if result && !self.command
   if response==bytes("8000000000000000")[0..size(response)-1] || response==bytes("FFFFFFFFFFFFFFFF")[0..size(response)-1]
    response=bytes("0000000000000000")[0..size(response)-1]
   end
   var value=self.bytes2real(response)
   if value !=0
    value*=self.pollItems[self.dp][3]
   end
   if self.pollItems[self.dp][6]==1 && value<self.pollItems[self.dp][5]
    value=self.pollItems[self.dp][5]
   else
    self.pollItems[self.dp][5]=value
   end
   var mvalue=nil
   if self.pollItems[self.dp][4]=="x"
    mvalue=self.maps.find(self.pollItems[self.dp][0])
   end
   if mvalue!=nil
    value=mvalue.find(int(value))
   else
    value=string.format("%.3f",value)
   end
   #print("MQTT:",self.baseTopic+self.pollItems[self.dp][0],value)
   mqtt.publish(self.baseTopic+self.pollItems[self.dp][0],value)
  elif result && self.command
   mqtt.publish(self.baseTopic+"response",f"{self.commands[0][0]},{self.commands[0][1]},{self.commands[0][2]},{self.commands[0][3]}: {response} - {self.bytes2real(response)}")
  elif !result
   print("ModBus error:",self.modBusError[response])
   mqtt.publish(self.baseTopic+"response",f"{self.commands[0][0]},{self.commands[0][1]},{self.commands[0][2]},{self.commands[0][3]}: {response} - {self.modBusError[response]}")
  end
 except .. as e
  print("Berry error:", e)
 end
 if self.command 
  self.commands.pop(0)
  self.command=false
 end
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
#    if self.dp<size(self.pollItems)-1 self.dp+=1 else self.dp=0 end
#    self.requestOutstanding=true
#    global.mbtcp.request(self.pollItems[self.dp][1]>40000 ? 3 : 4,self.pollItems[self.dp][1],self.pollItems[self.dp][2],/r,d -> self.callback(r,d))
   end
  end
  self.delay=self.stdDelay
 end
end #every_second

end #SmaMb

global.smamb=SmaMb()
tasmota.add_driver(global.smamb)
