--[[
Copyright (c) <2025>, Aaron Mitchell
All rights reserved.

This source code is licensed under the BSD-style license found in the
LICENSE file in the root directory of this source tree. 
]]--

-------------------------------------------------------------------------------------
-- TCP Class --
-------------------------------------------------------------------------------------
VERBOSE = false

local TCP = {}
TCP.__index = TCP

 -- Constructor
function TCP:new(deviceIp, devicePort, deviceKeepalive)
  local base = {
    address = deviceIp or "",
    port = devicePort or 23,
    keepalive_msg = deviceKeepalive,
    tcp = TcpSocket.New(),
    connected = false,
    reconnecting = false,
    heartbeat = Timer.New(),
    heartbeatTime = 5,
    verboseDebug = VERBOSE,
    status = {
      states = {
        ok = 0,
        compromised = 1,
        fault = 2,
        notPresent = 3,
        missing = 4,
        initialising = 5,
      }
    },    
  }

  -- Initialise base objects
  base.tcp.ReadTimeout = 0
  base.tcp.WriteTimeout = 0
  base.tcp.ReconnectTimeout = 5
  base.status.state = base.status.states.notPresent

  if base.verboseDebug then 
    print("TCP Connection created:")
    print("Address: " .. tostring(base.address))
    print("Port: " .. tostring(base.port))
    print("TCP object exists: " .. tostring(base.tcp ~= nil))
  end

  -- set metatable and return the base settings
  setmetatable(base, TCP) -- describes table behavior
  base:setupEventHandlers()
  return base
end

-- Methods
function TCP:sendCommand(cmd) 
  local success, err = pcall(function() -- error handling for issues writing to the socket
    return self.tcp:Write(cmd)
  end)
  if not success then
    print("sendCommand error: "..tostring(err)) 
  end
end

function TCP:Connect()
  print("TCP connecting to "..self.address..":"..self.port)
  self.tcp:Connect(self.address, self.port)
end

function TCP:Disonnect()
  print("TCP disconnecting...")
  self.tcp:Disconnect()
end

function TCP:isConnected()
  return self.tcp.IsConnected
end

function TCP:setupEventHandlers()
  local tcpInstance = self  -- Store reference to avoid scope issues  
  self.tcp.EventHandler = function(tcp, evt, err) --Event Handler for the TCP socket
    if evt == TcpSocket.Events.Connected then
        print("socket connected")
        if tcpInstance.keepalive_msg then
          tcpInstance.heartbeat:Start(tcpInstance.heartbeatTime)  -- start heartbeat timer
        end
        tcpInstance.connected = true 
        tcpInstance.reconnecting = false
        tcpInstance.status.state = tcpInstance.status.states.ok
        return
    elseif evt == TcpSocket.Events.Reconnect then
        if not tcpInstance.reconnecting or tcpInstance.verboseDebug then
          print("socket reconnecting...")
          tcpInstance.reconnecting = true
          tcpInstance.status.state = tcpInstance.status.states.initialising
        end
    elseif evt == TcpSocket.Events.Data then
        local message = tcp:ReadLine(TcpSocket.EOL.Any)
        if (message ~= nil) and (message ~= '') then
          if verboseDebug then 
            print("TCP Received: " .. message)
          end
          tcpInstance.dataCallback(message, tcpInstance)
        end
    elseif evt == TcpSocket.Events.Closed then
        print("socket closed by remote")
        tcpInstance.status.state = tcpInstance.status.states.compromised
        tcpInstance.connected = false
    elseif evt == TcpSocket.Events.Error then
        tcpInstance.status.state = tcpInstance.status.states.fault
        if tcpInstance.verboseDebug then
          print("socket error: " .. tostring(err))
        end
        tcpInstance.connected = false
    elseif evt == TcpSocket.Events.Timeout then
        print("Socket closed due to timeout")
        tcpInstance.status.state = tcpInstance.status.states.missing
        tcpInstance.connected = false
    else
        print("unknown socket event: " .. tostring(evt))
    end
  end

  self.heartbeat.EventHandler = function()
    if tcpInstance.connected then
        tcpInstance:sendCommand(tcpInstance.keepalive_msg)
        if tcpInstance.verboseDebug then 
          print("heartbeat sent")
        end
    end
  end
end
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
