set ns [new Simulator]

set K_port 80;	#The per-port ECN marking threshold
set service1_senders 4
set service2_senders 1
set K_0 16; #The per-queue ECN marking threshold of the first queue
set K_1 64; #The per-queue ECN marking threshold of the second queue
set W_0 1000; #The weight of the first queue
set W_1 4000; #The weight of the second queue

set RTT 0.0001
set DCTCP_g_ 0.0625
set ackRatio 1 
set packetSize 1460
set lineRate 10Gb

set simulationTime 0.02
set throughputSamplingInterval 0.0004

Agent/TCP set windowInit_ 10
Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set dctcp_ false
Agent/TCP set dctcp_g_ $DCTCP_g_
Agent/TCP set packetSize_ $packetSize
Agent/TCP set window_ 1256
Agent/TCP set slow_start_restart_ false
Agent/TCP set minrto_ 0.01 ; # minRTO = 10ms
Agent/TCP set windowOption_ 0
Agent/TCP/FullTcp set segsize_ $packetSize
Agent/TCP/FullTcp set segsperack_ $ackRatio; 
Agent/TCP/FullTcp set spa_thresh_ 3000;
Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms

Queue set limit_ 1000
Queue/WF2Q set queue_num_ 2
Queue/WF2Q set dequeue_ecn_marking_ 0
Queue/WF2Q set mean_pktsize_ $packetSize
Queue/WF2Q set port_thresh_ $K_port

set mytracefile [open mytracefile.tr w]
$ns trace-all $mytracefile
set throughputfile [open throughputfile.tr w]
set tracedir tcp_flows

proc finish {} {
	global ns mytracefile throughputfile
	$ns flush-trace
	close $mytracefile
	close $throughputfile
	exit 0
}

set switch [$ns node]
set receiver [$ns node]

$ns simplex-link $switch $receiver $lineRate [expr $RTT/4] WF2Q
$ns simplex-link $receiver $switch $lineRate [expr $RTT/4] DropTail

set L [$ns link $switch $receiver] 
set q [$L set queue_]
$q set-weight 0 $W_0
$q set-weight 1 $W_1
$q set-thresh 0 $K_0
$q set-thresh 1 $K_1

#Service type 1 senders
for {set i 0} {$i<$service1_senders} {incr i} {
	set n1($i) [$ns node]
    $ns duplex-link $n1($i) $switch $lineRate [expr $RTT/4] DropTail
	set tcp1($i) [new Agent/TCP/FullTcp/Sack]
	set sink1($i) [new Agent/TCP/FullTcp/Sack]
	$tcp1($i) set serviceid_ 0
	$sink1($i) listen
	
	$tcp1($i) attach [open ./$tracedir/$i.tr w]
	$tcp1($i) set bugFix_ false
	$tcp1($i) trace cwnd_
	$tcp1($i) trace ack_
    #$tcp1($i) trace srtt_
	#$tcp1($i) trace rtt_
	#$tcp1($i) trace ssthresh_
	#$tcp1($i) trace nrexmit_
	#$tcp1($i) trace nrexmitpack_
	#$tcp1($i) trace nrexmitbytes_
	#$tcp1($i) trace ncwndcuts_
	#$tcp1($i) trace ncwndcuts1_
	#$tcp1($i) trace dupacks_
	
	$ns attach-agent $n1($i) $tcp1($i)
    $ns attach-agent $receiver $sink1($i)
	$ns connect $tcp1($i) $sink1($i)       
	
	set ftp1($i) [new Application/FTP]
	$ftp1($i) attach-agent $tcp1($i)
	$ftp1($i) set type_ FTP
	$ns at [expr 0.0] "$ftp1($i) start"
}

#Service type 2 senders
for {set i 0} {$i<$service2_senders} {incr i} {
	set n2($i) [$ns node]
    $ns duplex-link $n2($i) $switch $lineRate [expr $RTT/4] DropTail
	set tcp2($i) [new Agent/TCP/FullTcp/Sack]
	set sink2($i) [new Agent/TCP/FullTcp/Sack]
	$tcp2($i) set serviceid_ 1
	$sink2($i) listen
	
	$tcp2($i) attach [open ./$tracedir/[expr $i+$service1_senders].tr w]
	$tcp2($i) set bugFix_ false
	$tcp2($i) trace cwnd_
	$tcp2($i) trace ack_
    #$tcp2($i) trace srtt_
	#$tcp2($i) trace rtt_
	#$tcp2($i) trace ssthresh_
	#$tcp2($i) trace nrexmit_
	#$tcp2($i) trace nrexmitpack_
	#$tcp2($i) trace nrexmitbytes_
	#$tcp2($i) trace ncwndcuts_
	#$tcp2($i) trace ncwndcuts1_
	#$tcp2($i) trace dupacks_
	
	$ns attach-agent $n2($i) $tcp2($i)
    $ns attach-agent $receiver $sink2($i)
	$ns connect $tcp2($i) $sink2($i)       
	
	set ftp2($i) [new Application/FTP]
	$ftp2($i) attach-agent $tcp2($i)
	$ftp2($i) set type_ FTP
	$ns at [expr $simulationTime/2] "$ftp2($i) start"
}

proc record {} {
	global ns throughputfile throughputSamplingInterval service1_senders service2_senders tcp1 sink1 tcp2 sink2 
	
	#Get the current time
	set now [$ns now]
	
	#Initialize the output string 
	set str $now
	
	set bw1 0
	for {set i 0} {$i<$service1_senders} {incr i} {
		set bytes [$tcp1($i) set bytes_]
		set bw1 [expr $bw1+$bytes]
		$tcp1($i) set bytes_ 0	
	}
	append str " "
	append str [expr int($bw1/$throughputSamplingInterval*8/1000000)];	#throughput in Mbps
	
	set bw2 0
	for {set i 0} {$i<$service2_senders} {incr i} {
		set bytes [$tcp2($i) set bytes_]
		set bw2 [expr $bw2+$bytes]
		$tcp2($i) set bytes_ 0	
	}
	append str " "
	append str [expr int($bw2/$throughputSamplingInterval*8/1000000)];	#throughput in Mbps
	
	puts $throughputfile $str 
	
	#Set next callback time
	$ns at [expr $now+$throughputSamplingInterval] "record"
	
}

$ns at 0.0 "record"
$ns at [expr $simulationTime] "finish"
$ns run