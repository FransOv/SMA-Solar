class MbTcp
var mb
var id
var tcp
# Read Holding registers: mbtcp.request(3,0,4,,/r,d -> print(r,d)) 
# TX: 0003 0000 0006 3C 03 0000 0004
# RX: 0003 0000 000B 3C 03 08 3039 0929 5CA0 1A85

# Write Holding registers: mbtcp.request(16,0,4,bytes("00FF010001010102"))
# TX: 0006 0000 000F 3C 10 0000 0004 08 04D2 00EA 0929 02A6
# RX: 0006 0000 0006 3C 10 0000 0004

def init()
 self.mb=map()  #elements: status, mbs, cb, function, address, length, data
 self.mb.insert("status",2) #0:closed, 1:connecting 2:listening, 3:request qeued 4:request outstanding, 9:timeout
 self.mb.insert("mbs","192.168.2.128")
 self.tcp=tcpclientasync()
 self.id=1
end #init

def timeout()
 self.mb["status"]=9
end #timeout

def connect(mbs,id)
 if self.mb["status"]==0 || self.mb["status"]==9
  self.mb["status"]=1
  self.id=id
  if self.tcp!=nil
   self.tcp.close()
  end
  self.mb["mbs"]=mbs
  return self.tcp.connect(mbs,502)
 end
end #connect

def request(mbfunction, address, length, cb, data)
 if self.mb["status"]==1 || self.mb["status"]==2
  self.mb["function"]=int(mbfunction)
  self.mb["address"]=int(address)
  self.mb["length"]=int(length)
  self.mb["data"]=data
  self.mb["cb"]=cb
  self.mb["status"]=3
 else
  cb(false,bytes("FF"))
 end
end #request

def resetrequest()
  self.mb.remove("cb")
  self.mb.remove("function")
  self.mb.remove("address")
  self.mb.remove("length")
  self.mb.remove("data")
  tasmota.remove_timer("TimeOut")
end

def close()
 if self.mb["status"] != 0 
#  self.mb.remove("mbs")
  if self.mb["status"] > 1
   self.resetrequest()
  end
  self.mb["status"]=0
  if self.tcp.connected()
   self.tcp.close()
  end
  return true
 else
  return false
 end
end #close

def every_250ms()
 if !self.tcp.connected() && self.mb["status"] > 2
  self.tcp.close()
  print("Connect: ",self.tcp.connect(self.mb["mbs"],502))
  return
 end

 if self.mb["status"]==1
  if self.tcp.listening()
   self.mb["mbs"]=self.tcp.info()["remote_addr"]
   self.mb["status"]=2
  end
  
 elif self.mb["status"]==3
  var mbdata=bytes("00010000000603")
  mbdata[6]=self.id
  mbdata.add(self.mb["function"],1)
  mbdata.add(self.mb["address"],-2)
  mbdata.add(self.mb["length"],-2)
  if self.mb["data"] != nil
   mbdata.set(4, 7+size(self.mb["data"]), -2)
   mbdata.add(size(self.mb["data"]), 1)
   mbdata+=self.mb["data"]
  end
   print(self.mb,mbdata)
 if cb !=nil
   tasmota.set_timer(5000,/->self.timeout(),"TimeOut")
  end
  self.tcp.write(mbdata) 
  self.mb["status"]=4
  
 elif self.mb["status"] == 4
  if self.tcp.available() > 0
   var tcpdata=self.tcp.readbytes()
   #print(tcpdata)
   var mbfunction=tcpdata[7]&0x7F
   var result=tcpdata[7]&0x80==0
   var mbdata=bytes() 
   if (mbfunction==1 || mbfunction==3 || mbfunction==4) && result
    mbdata=tcpdata[9..]
   elif !result
    mbdata=tcpdata[8]
   end
   var cb=self.mb.find("cb")
   self.resetrequest()
   self.tcp.close()
   self.mb["status"]=2
   if cb!=nil
    cb(result, mbdata)
   end
  end
  
 elif self.mb["status"]==9
  #print(self.mb, self.tcp.info())
  var callback=self.mb.find("cb")
  self.resetrequest()
  self.mb["status"]=2
  self.tcp.close()
  if callback!=nil
   callback(false,bytes("09"))
  end
 end

end #every_250ms

end #MbTcp

tasmota.remove_driver(global.mbtcp)
global.mbtcp=MbTcp()
tasmota.add_driver(global.mbtcp)