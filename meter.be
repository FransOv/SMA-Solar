class eMeter
var values # map of lists Key: P1-Code, Value: [OBIS Code, Data Prefix, Multiplier, Value]
var udpSocket
var emHeader 
var emId
var serial
var dataValid
var bri
var hue

def init()
 import mqtt
 self.serial=bytes("00000000")
 self.serial.set(0,1901567274,-4)

 self.emHeader=bytes().fromstring("SMA")+bytes("000004")+bytes("02A000000001")+bytes("FFFF00106069") # Data length @ 12(2)
 self.emId=bytes("015D")+self.serial+bytes("00000000") # Millis @ 6 (4)
 self.dataValid=false
 self.values=
  [
  ["pwr_imp","1.1.4",bytes("00010400"),10000.0,0],
  ["enrg_imp","1.1.8.1",bytes("00010800"),3600000.0,0],
  ["pwr_exp","1.2.4",bytes("00020400"),10000.0,0],
  ["enrg_exp","1.2.8.1",bytes("00020800"),3600000.0,0],
  ["pwr_imp_r","1.3.4",bytes("00030400"),10000.0,bytes("00000000")],
  ["enrg_imp_r","1.3.8.1",bytes("00030800"),3600000.0,bytes("0000000000000000")],
  ["pwr_exp-r","1.4.4",bytes("00040400"),10000.0,bytes("00000000")],
  ["enrg_exp_r","1.4.8.1",bytes("00040800"),3600000.0,bytes("0000000000000000")],
  ["pwr_imp_a","1.1.9",bytes("00090400"),10000.0,0],
  ["enrg_imp_a","1.9.8.1",bytes("00090800"),3600000.0,0],
  ["pwr_exp_a","1.10.4",bytes("000A0400"),10000.0,0],
  ["enrg_exp_a","1.10.8.1",bytes("000A0800"),3600000.0,0],
  ["fact_tot","1.13.4",bytes("000D0400"),1000.0,bytes("000003E8")],
  ["freq","1.14.4",bytes("000e0400"),1000.0,bytes("0000C350")],
  
  ["l1_pwr_imp","1.21.4",bytes("00150400"),10000.0,0],
  ["l1_enrg_imp","1.21.8",bytes("00150800"),3600000.0,0],
  ["l1_pwr_exp","1.22.4",bytes("00160400"),10000.0,0],
  ["l1_enrg_exp","1.22.8",bytes("00160800"),3600000.0,0],
  ["l1_pwr_imp_r","1.23.4",bytes("00170400"),10000.0,bytes("00000000")],
  ["l1_enrg_imp_r","1.23.8",bytes("00170800"),3600000.0,bytes("0000000000000000")],
  ["l1_pwr_exp_r","1.24.4",bytes("00180400"),10000.0,bytes("00000000")],
  ["l1_enrg_exp_r","1.24.8",bytes("00180800"),3600000.0,bytes("0000000000000000")],
  ["l1_pwr_imp_a","1.29.4",bytes("001D0400"),10000.0,0],
  ["l1_enrg_imp_a","1.29.8",bytes("001D0800"),3600000.0,0],
  ["l1_pwr_exp_a","1.30.4",bytes("001E0400"),10000.0,0],
  ["l1_enrg_exp_a","1.30.8",bytes("001E0800"),3600000.0,0],
  ["amp_l1","1.31.4",bytes("001F0400"),1000.0,0],
  ["volts_l1","1.32.4",bytes("00200400"),1000.0,0],
  ["fact_l1","1.33.4",bytes("00210400"),1000.0,bytes("000003E8")],
  
  ["l2_pwr_imp","1.41.4",bytes("00290400"),10000.0,0],
  ["l2_enrg_imp","1.41.8",bytes("00290800"),3600000.0,0],
  ["l2_pwr_exp","1.42.4",bytes("002A0400"),10000.0,0],
  ["l2_enrg_exp","1.42.8",bytes("002A0800"),3600000.0,0],
  ["l2_pwr_imp_r","1.43.4",bytes("002B0400"),10000.0,bytes("00000000")],
  ["l2_enrg_imp_r","1.43.8",bytes("002B0800"),3600000.0,bytes("00000000000000000")],
  ["l2_pwr_exp_r","1.44.4",bytes("002C0400"),10000.0,bytes("00000000")],
  ["l2_enrg_exp_r","1.44.8",bytes("002C0800"),3600000.0,bytes("0000000000000000")],
  ["l2_pwr_imp_a","1.49.4",bytes("00310400"),10000.0,0],
  ["l2_enrg_imp_a","1.49.8",bytes("00310800"),3600000.0,0],
  ["l2_pwr_exp_a","1.50.4",bytes("00320400"),10000.0,0],
  ["l2_enrg_exp_a","1.50.8",bytes("00320800"),3600000.0,0],
  ["amp_l2","1.51.4",bytes("00330400"),1000.0,0],
  ["volts_l2","1.52.4",bytes("00340400"),1000.0,0],
  ["fact_l2","1.53.4",bytes("00350400"),1000.0,bytes("000003E8")],
  
  ["l3_pwr_imp","1.61.4",bytes("003D0400"),10000.0,0],
  ["l3_enrg_imp","1.61.8",bytes("003D0800"),3600000.0,0],
  ["l3_pwr_exp","1.62.4",bytes("003E0400"),10000.0,0],
  ["l3_enrg_exp","1.62.8",bytes("003E0800"),3600000.0,0],
  ["l3_pwr_imp_r","1.63.4",bytes("003F0400"),10000.0,bytes("00000000")],
  ["l3_enrg_imp_r","1.63.8",bytes("003F0800"),3600000.0,bytes("0000000000000000")],
  ["l3_pwr_exp_r","1.64.4",bytes("00400400"),10000.0,bytes("00000000")],
  ["l3_enrg_exp_r","1.64.8",bytes("00400800"),3600000.0,bytes("0000000000000000")],
  ["l3_pwr_imp_a","1.69.4",bytes("00450400"),10000.0,0],
  ["l3_enrg_imp_a","1.69.8",bytes("00450800"),3600000.0,0],
  ["l3_pwr_exp_a","1.70.4",bytes("00460400"),10000.0,0],
  ["l3_enrg_exp_a","1.70.8",bytes("00460800"),3600000.0,0],
  ["amp_l3","1.71.4",bytes("00470400"),1000.0,0],
  ["volts_l3","1.72.4",bytes("00480400"),1000.0,0],
  ["fact_l3","1.73.4",bytes("00490400"),1000.0,bytes("000003E8")]
  ]
 global.pwr=0
 self.udpSocket=udp()
 self.udpSocket.begin_multicast("239.12.255.254",9522)
 mqtt.unsubscribe("tele/tasmota-esmr/DSMR5")
 mqtt.subscribe("tele/tasmota-esmr/DSMR5", /t,idx,ps,pb -> self.smr(t,idx,ps,pb))
end # init


def smr(topic,idx,payload_s,payload_b)
 import json
 var smv=json.load(payload_s)
 for val : self.values
  var v=smv.find(val[0])
  if v != nil
   val[4]=self.num2bytes(v*val[3],val[2][2])
  else
   if val[0] == "enrg_imp"
    v=smv["enrg_imp_t1"]+smv["enrg_imp_t2"]
   elif val[0] == "enrg_exp"
    v=smv["enrg_exp_t1"]+smv["enrg_exp_t2"]
   elif val[0] == "pwr_imp_a"
    v=smv["pwr_imp"]
   elif val[0] == "enrg_imp_a"
    v=smv["enrg_imp_t1"]+smv["enrg_imp_t2"]
   elif val[0] == "pwr_exp_a"
    v=smv["pwr_exp"]
   elif val[0] == "enrg_exp_a"
    v=smv["enrg_exp_t1"]+smv["enrg_exp_t2"]

   elif val[0] == "l1_enrg_imp"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l1_enrg_exp"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "l1_pwr_imp_a"
    v=smv["l1_pwr_imp"]
   elif val[0] == "l1_enrg_imp_a"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l1_pwr_exp_a"
    v=smv["l1_pwr_exp"]
   elif val[0] == "l1_enrg_exp_a"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "amp_l1"
    v=(smv["l1_pwr_imp"]+smv["l1_pwr_exp"])*1000.0/smv["volts_l1"]


   elif val[0] == "l2_enrg_imp"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l2_enrg_exp"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "l2_pwr_imp_a"
    v=smv["l2_pwr_imp"]
   elif val[0] == "l2_enrg_imp_a"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l2_pwr_exp_a"
    v=smv["l2_pwr_exp"]
   elif val[0] == "l2_enrg_exp_a"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "amp_l2"
    v=(smv["l2_pwr_imp"]+smv["l2_pwr_exp"])*1000.0/smv["volts_l2"]

   elif val[0] == "l3_enrg_imp"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l3_enrg_exp"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "l3_pwr_imp_a"
    v=smv["l3_pwr_imp"]
   elif val[0] == "l3_enrg_imp_a"
    v=(smv["enrg_imp_t1"]+smv["enrg_imp_t2"])/3
   elif val[0] == "l3_pwr_exp_a"
    v=smv["l3_pwr_exp"]
   elif val[0] == "l3_enrg_exp_a"
    v=(smv["enrg_exp_t1"]+smv["enrg_exp_t2"])/3
   elif val[0] == "amp_l3"
    v=(smv["l3_pwr_imp"]+smv["l3_pwr_exp"])*1000.0/smv["volts_l3"]
   end
   if v != nil
    val[4]=self.num2bytes(v*val[3],val[2][2])
   end
  end
 end
 global.pwr=smv["pwr_exp"]-smv["pwr_imp"]
 self.dataValid=true
end # smr

def num2bytes(value,length) # only positive numbers length 1, 2, 4 or 8
 var b=bytes()
 if length<=4
  b.add(int(value),-length)
 elif length==8
   b=bytes("0000")
   b.add(int(value/65535),-4)  # 3600000/65535 will limit accuracy to 20 Wh
   b+=bytes("0000")
#  b.add(int(value/4294967296.0),-4)
#  b.add(int(value%4294967296.0),-4)
 else
  print(value,length)
 end
 return b
end # num2bytes

def every_second()
 if self.dataValid
  self.emId.set(6,int(tasmota.rtc("local")*1000),-4)
  var dg=self.emHeader+self.emId
  var dl=12
  for v : self.values
   dg+=(v[2]+v[4])
   dl+=4+v[2][2]
  end
  dg+=(bytes("9000000002030452")+bytes("00000000"))
  dl+=8
  dg.set(12,dl,-2)
  #print(dg.size(),dl,dg[0..63].tohex()+"||"+dg[dg.size()-64..dg.size()-1].tohex())
  self.udpSocket.send_multicast(dg)
  while self.udpSocket.read() != nil end # prevent unread messages from blocking communication
 end

 self.hue=global.pwr>0 ? 120 : 0
 self.bri=global.pwr>0 ? int(global.pwr*255/10) : -int(global.pwr*255/20)
 light.set({"bri":self.bri,"hue":self.hue,"sat":255})
end # every_second

end #eMeter

tasmota.remove_driver(global.emeter)
tasmota.add_driver(global.emeter := eMeter())
