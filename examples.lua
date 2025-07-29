-- Initialise
tcpConnection = TCP:new(MyDeviceIPaddress, MyDevicePort)

-- Set keepalive command
tcpConnection:setKeepalive(MyKeepaliveCommand)

-- Unitialise status
tcpConnection:setStatus(tcpConnection.status.states.initialising)

-- Make connection
tcpConnection:Connect()
