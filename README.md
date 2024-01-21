# vsxexport
Bash script for exporting Gaia configuration of VS0 as well as all other Virtual Sytems (settings like BGP config, routemaps etc.). It also saves the current routing info, useful for diff checks during maintenance windows. Configuration files like local.arp and fwkern.conf, simkern.conf (see sk101515) are also exported.

# Version History

0.1   Initial script  
0.2   Display status on screen  
0.3   Implemented new method to find Virtual System IDs  
0.4   Extra Clish commands added to Clish script and added Affinity + Multi-Queue settings  
0.5   Modified output format (splitted conf and log files)  
0.6   Rewritten backup of VSes other than VS0  
0.7   Fix: -i option added to Clish batch command to ignore failures  
0.8   Fix: Cleanup temporary files and added "set virtual-system" to export of Clish config per Virtual System  
0.8.1 Export Clish config of all Virtual Systems (other than VS0) to VS-all.config  
0.9   Added support for 3.10 kernel  
0.9.1 Implemented some "QA" fixes before 1.0 release of this script  
1.0   Public release 1.0  
1.0.1  Output of other Virtual Systems now have same style as output of VS0  
1.0.2  Added commands starting with "set prefix-" to export of Clish config per Virtual System  
1.0.3  Added commands starting with "set bootp" to export of Clish config per Virtual System  
1.0.4  Added commands starting with "set route-redistribution" to export of Clish config per Virtual System  
1.0.5  Added commands starting with "add arp" to export of Clish config per Virtual System  
       Added commands starting with "set max-path-splits" to export of Clish config per Virtual System  
       Added commands starting with "set inbound-route-filter" to export of Clish config per Virtual System  
       Added commands starting with "set pbr" to export of Clish config per Virtual System  
       Minor change in CoreXL status check  
1.1    Added self-update mechanism  
1.2    Added status of Dynamic Balancing  
       Added status of SecureXL Fast Accelerator  
       Log information about interfaces  
1.3    Log active proxy ARP entries per Virtual System  
1.4    Added commands starting with "set aggregate" to export of Clish config per Virtual System  
       Log output of cpinfo -y all  
       Log output of netstat -rn (VS0)  
       
This project is licensed under the terms of the MIT license.
