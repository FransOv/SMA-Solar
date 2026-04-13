class BatteryControl
# schedule resolution 30 minutes. nil: Self consumption, 0: Manual, >0: Charge at x kW, >0: Discharge at x kW
var schedule
var power
var normal
var manual
var charge 
var sched
var debug

def init()
 import mqtt
 self.debug=true
 self.schedule=[]
 self.power=4.5
 for ix : 0..47 self.schedule.push(nil) end
# modbus command [Function,Address,Length,Callback,Data]
 self.normal=[16,40151,2,/r,d -> self.cbd(r,d),bytes().add(803,-4)]
 self.manual=[16,40151,2,/r,d -> self.cbcharge(r,d),bytes().add(802,-4)]
 self.charge=[16,40149,2,/r,d -> self.cbd(r,d),bytes().add(0,-4)]
 var dt=tasmota.time_dump(tasmota.rtc("local"))
 self.sched=dt["hour"]*2+int(dt["min"]/30)
 tasmota.add_rule("power1#state",/->self.scheduleonoff())
 tasmota.add_rule("power2#state",/->self.pauseonoff())
 mqtt.unsubscribe("sma_solar/setschedule")
 mqtt.subscribe("sma_solar/setschedule",/t,idx,ps,pb -> self.setschedule(t,idx,ps,pb))
 tasmota.remove_cron("nextperiod")
 tasmota.add_cron("5 0,30 * * * *", /->self.nextperiod(), "nextperiod")
 if self.debug print("Started: ",self.schedule) end
end #init

def setschedule(t,idx,ps,pb) # {"enable": bool,"lowamhour":0..6,"highamhour":7..11,lowpmhour":12..16,"highpmhour":16..20}
 import json
 var pj=json.load(ps)
 if pj != nil && pj.find("enable")!=nil && (pj["enable"]==false || ((pj.find("lowamhour")!=nil || pj.find("lowpmhour")!=nil) && (pj.find("highamhour")!=nil || pj.find("highpmhour")!=nil)))
  tasmota.set_power(0,false)
  tasmota.set_power(1,false)
  self.schedule=[]
  for ix : 0..47 self.schedule.push(nil) end
  if self.power<0 # summer mode
   if pj["enable"] && pj.find("highamhour")!=nil
     self.schedule[pj["highamhour"]*2]=self.power
     self.schedule[pj["highamhour"]*2+1]=self.power
   end
  else # Winter mode
   if pj.find("lowamhour")!=nil && pj["lowamhour"]>=0 && pj["lowamhour"]<=6
    self.schedule[pj["lowamhour"]*2]=self.power
    self.schedule[pj["lowamhour"]*2+1]=self.power
    if pj.find("highamhour") != nil
     for ix : pj["lowamhour"]*2+2..6*2-1
      self.schedule[ix]=0
     end
    else
     for ix : pj["lowamhour"]*2+2..pj["highpmhour"]*2-2
      self.schedule[ix]=0
     end
    end
   end
   if pj.find("lowpmhour")!=nil && pj["lowpmhour"]>=12 && pj["lowpmhour"]<16
    self.schedule[pj["lowpmhour"]*2]=self.power
    self.schedule[pj["lowpmhour"]*2+1]=self.power
    if pj.find("highpmhour") != nil
     for ix : pj["lowpmhour"]*2+2..pj["highpmhour"]*2-3
      self.schedule[ix]=0
     end
    end
   end
  end
  tasmota.set_power(0,pj["enable"])
  if self.debug print("Set schedule: ",ps,self.schedule) end
  return true
 else
  print("Invalid set schedule: ",ps)
  return false
 end
end #setschedule

def scheduleonoff()
 import mqtt
 tasmota.set_power(1,false)
 if tasmota.get_power(0)
  if self.schedule[self.sched]==nil
   global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
   mqtt.publish("sma_solar/charge_state","Auto")
  else
   global.mbtcp.request(self.manual[0],self.manual[1],self.manual[2],self.manual[3],self.manual[4])
   if self.schedule[self.sched]==0
    mqtt.publish("sma_solar/charge_state","Off")
   else
    mqtt.publish("sma_solar/charge_state",f"Scheduled {self.schedule[self.sched]:%.1f} kW")
   end
  end
 else
  global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
  mqtt.publish("sma_solar/charge_state","Auto")
 end
end #scheduleonoff

def pauseonoff()
 import mqtt
 if tasmota.get_power(0)
  if tasmota.get_power(1)
   global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
   mqtt.publish("sma_solar/charge_state","paused")
  else
   if self.schedule[self.sched]==nil
    global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
    mqtt.publish("sma_solar/charge_state","auto")
   else
    global.mbtcp.request(self.manual[0],self.manual[1],self.manual[2],self.manual[3],self.manual[4])
    if self.schedule[self.sched]==0
     mqtt.publish("sma_solar/charge_state","Off")
    else
     mqtt.publish("sma_solar/charge_state",f"Scheduled {self.schedule[self.sched]:%.1f} kW")
    end
   end
  end
 end
end #pauseonoff

def cbcharge(result,data)
 import mqtt
 if result
  if self.debug print("MB command:",self.charge[0],self.charge[1],self.charge[2],self.charge[3],bytes().add(int(self.schedule[self.sched]*1000),-4)) end
  global.mbtcp.request(self.charge[0],self.charge[1],self.charge[2],self.charge[3],bytes().add(int(-self.schedule[self.sched]*1000),-4))
 else
  print("ModBus Error",data)
  mqtt.publish("sma_solar/charge_state",f"Modbus error {data:x}")
 end
end #cbcharge

def cbd(result,data)
 import mqtt
 var dt=tasmota.time_dump(tasmota.rtc("local"))
 if result
  if self.debug print(f"Time {dt['hour']:%i}:{dt['min']:%i} callback",self.sched, self.schedule[self.sched],data) end
 else
  print("ModBus Error",data)
  mqtt.publish("sma_solar/charge_state",f"Modbus error {data:x}")
 end
end #cbd

def nextperiod()
 import mqtt
 var dt=tasmota.time_dump(tasmota.rtc("local"))
 self.sched=dt["hour"]*2+int(dt["min"]/30)
 if self.debug print(self.sched,self.schedule[self.sched]) end
 if tasmota.get_power(0) && !tasmota.get_power(1) && (self.schedule[self.sched]!=self.schedule[self.sched==0 ? 47 : self.sched-1] || (self.schedule[self.sched]!=nil && self.schedule[self.sched]!=0))
  if self.schedule[self.sched]==nil 
   if self.debug print("Send ",self.normal) end
   global.mbtcp.request(self.normal[0],self.normal[1],self.normal[2],self.normal[3],self.normal[4])
  else
   if self.debug print("Send",self.manual) end
   global.mbtcp.request(self.manual[0],self.manual[1],self.manual[2],self.manual[3],self.manual[4])
  end
  if self.schedule[self.sched]==nil
   mqtt.publish("sma_solar/charge_state","auto")
  elif self.schedule[self.sched]==0
   mqtt.publish("sma_solar/charge_state","Off")
  else
   mqtt.publish("sma_solar/charge_state",f"Scheduled {self.schedule[self.sched]:%.1f} kW")
  end
 end
end #nextperiod


end #BatteryControl

tasmota.remove_driver(global.battctl)
global.battctl=BatteryControl()
tasmota.add_driver(global.battctl)
