import os
import sys
import string
import time
import random
import math

#This function is to print usage of this script
def usage():
	sys.stderr.write('This script is used to generate dynamic flow workloads:\n')
	sys.stderr.write('trace_generator.py [traffic distribution file] [load] [link capacity (Mbps)] [flow number] [host number] [service number] [output file]\n')

#http://preshing.com/20111007/how-to-generate-random-timings-for-a-poisson-process/
#Return next time interval (ms) 
def nextTime(rateParameter):
	#We use round function to get a integer
    return round(-math.log(1.0 - random.random()) / rateParameter)

def serviceID(services_load, service_num):
	if len(services_load)!=service_num:
		print 'Error!'
	else:
		x=random.random()
		for i in range(len(services_load)):
			if x<=services_load[i]:
				return i
			else:
				i=i+1
		
#Given a flow distribution and a random number in (0,1), return a flow size (KB)
def flowsize(distribution, random):
	i=0
	for var in distribution:
		if var[0]>random:
			x1=distribution[i-1][0]
			x2=distribution[i][0]
			y1=distribution[i-1][1]
			y2=distribution[i][1]
			value=int(((y2-y1)/(x2-x1)*random+(x2*y1-x1*y2)/(x2-x1))*1448/1024)
			return value
		elif var[0]==random:
			return int(var[1]*1448/1024)
		else:
			i=i+1
	#By default, return 0
	return 0
	
#main function
if len(sys.argv)!=8:
	usage()
else:
	traffic_filename=sys.argv[1]
	load=float(sys.argv[2])
	capacity=float(sys.argv[3])
	flow_num=int(sys.argv[4])
	host_num=int(sys.argv[5])
	service_num=int(sys.argv[6])
	output_filename=sys.argv[7]
	
	#Initialize flow distribution 
	distribution=[]
	#Get traffic distribution line by line from input file
	traffic_file=open(traffic_filename,'r')
	lines=traffic_file.readlines()
	i=0
	for line in lines:
		tmp=line.split()
		if len(tmp)>=2:
			distribution.append([float(tmp[1]),float(tmp[0])])
			i=i+1
	traffic_file.close()
	
	#Generate flow size
	flows=[]
	for i in range(flow_num):
		flows.append(flowsize(distribution,random.random()))
	
	#Get average throughput
	throughput=load*capacity
	#Get average flow size
	avg=sum(flows)/len(flows)
	#Get average number of requests per second 
	num=throughput*1024*1024/(avg*1024*8) 
	#Get average request rate (number of requests every 1 ms)
	rate=num/1000 
	
	#Generate time interval
	times=[]
	for i in range(flow_num):
		#Get time interval (sleep time) 
		times.append(nextTime(rate)) 
	
	#Generate service load 
	services_load=[]
	for i in range(service_num):
		services_load.append(random.random())
				
	for i in range(1,service_num):
		services_load[i]=services_load[i-1]+services_load[i]
	
	for i in range(service_num):
		services_load[i]=services_load[i]/services_load[service_num-1]
	
	#Per service flow number 
	services_flow=[]
	for i in range(service_num):
		services_flow.append(0)
	
	#Write trace results into output file
	#Trace format: time_interval flow_size host_id service_id 
	output_file=open(output_filename,'w')
	for i in range(flow_num):
		service_id=serviceID(services_load,service_num)
		services_flow[service_id]+=1
		output_file.write(str(times[i])+' '+str(flows[i])+' '+str(random.randint(0,host_num-1))+' '+str(service_id)+'\n')
	output_file.close()
	
	print 'Auto generate '+str(len(flows))+' flows:'
	print 'The average flow size: '+str(avg)+' KB'
	print 'The average request speed: '+str(num)+' requests/second'
	print 'Dynamic flow emulation will last for about '+str(len(flows)/num)+' seconds'
	print services_load
	print services_flow
	print 'Done'
	
