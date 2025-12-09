class BatteryControl
# schedule resolution 30 minutes. -1: Self consumption, 0: Manual, >0 Charge at x kW
static var schedule=[-1,-1,2.5,2.5,2.5,2.5,2.5,2.5,2.5,2.5,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,3,3,3,3,3,3,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
# modbus command [Function,Address,Length,Callback,Data]
var normal
var manual
var charge

static var interval=60
var seconds
var sched

def init()
 self.seconds=60
 self.normal=[16,40151,2,/r,d -> self.cbd(r,d),bytes().add(803,-4)]
 self.manual=[16,40151,2,/r,d -> self.cbcharge(r,d),bytes().add(802,-4)]
 self.charge=[16,40149,2,/r,d -> self.cbd(r,d),bytes().add(0,-4)]
 var dt=tasmota.time_dump(tasmota.rtc("local"))
 self.sched=dt["hour"]*2+int(dt["min"]/30)
 tasmota.add_rule("power1#state=0",/->self.scheduleoff())
end #init

def scheduleoff()
 import mqtt
 if self.schedule[self.sched]!=-1
  global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
  mqtt.publish("sma_solar/charge_state","Auto")
 end
end #scheduleoff

def cbcharge(result,data)
 import mqtt
 if result
#  print("MB command:",self.charge[0],self.charge[1],self.charge[2],self.charge[3],bytes().add(-int(self.schedule[self.sched]*1000),-4))
  global.mbtcp.request(self.charge[0],self.charge[1],self.charge[2],self.charge[3],bytes().add(-int(self.schedule[self.sched]*1000),-4))
 else
  print("ModBus Error",data)
  mqtt.publish("sma_solar/charge_state",f"Modbus error {data:x}")
 end
end #cbcharge

def cbd(result,data)
 import mqtt
 var dt=tasmota.time_dump(tasmota.rtc("local"))
 if result
#  print(f"Time {dt['hour']:%i}:{dt['min']:%i} callback",self.sched, self.schedule[self.sched],data)
 else
  print("ModBus Error",data)
  mqtt.publish("sma_solar/charge_state",f"Modbus error {data:x}")
 end
end #cbd

def every_second()
 import mqtt
 if self.seconds<self.interval
  self.seconds+=1
 else
  self.seconds=0
  var dt=tasmota.time_dump(tasmota.rtc("local"))
  if dt["min"]%30==0 
   self.sched=dt["hour"]*2+int(dt["min"]/30)
   if tasmota.get_power(0) && (self.schedule[self.sched]!=self.schedule[self.sched==0 ? self.schedule[47] : self.sched-1] || self.schedule[self.sched]>0)
    var mbcmd=[]
    if self.schedule[self.sched]==-1 
     mbcmd=self.normal
    else
     mbcmd=self.manual
    end
#    print(f"Time {dt['hour']:%i}:{dt['min']:%i}",self.sched, self.schedule[self.sched], mbcmd)
#    print("MB command:",mbcmd[0],mbcmd[1],mbcmd[2],mbcmd[3],mbcmd[4])
    global.mbtcp.request(mbcmd[0],mbcmd[1],mbcmd[2],mbcmd[3],mbcmd[4])
    var charge_state
    if self.schedule[self.sched]==-1
     charge_state="Auto"
    elif self.schedule[self.sched]==0
     charge_state="Off"
    else
     charge_state=f"Scheduled {self.schedule[self.sched]:%.1f} kW"
    end
    mqtt.publish("sma_solar/charge_state",charge_state)
   end
  end
 end
end #every_second


end #BatteryControl

tasmota.remove_driver(global.battctl)
global.battctl=BatteryControl()
tasmota.add_driver(global.battctl)