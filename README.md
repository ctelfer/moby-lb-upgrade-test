Test Procedure for a Swarm Upgrade Without Service Interruption
======================

Building and install images:
    # ON LOCAL MACHINE:
    #  * build images and docker-compose.yml file
    $ ./setup.sh MYNAME


Start up testkit and promote 2 managers:
    # ON LOCAL MACHINE:
    #  * create a cluster with 5 macines: 3 managers and 2 workers
    $ testkit create 5 0 --parallel --engine ee-2.1 --name=tk1706 --debug
    $ testkit machine ssh tk1706-ubuntu-0 docker node promote tk1706-ubuntu-1
    $ testkit machine ssh tk1706-ubuntu-0 docker node promote tk1706-ubuntu-2


Log into testkit:
    # ON LOCAL MACHINE:
    $ testkit machine ssh tk1706-ubuntu-0


Clone repo for compose and start service:
    # ON LOCAL MACHINE:
    #  * start the test service to run during upgrade
    $ (eval "$(testkit machine env tk1706-ubuntu-0)" && 
       docker stack deploy -c docker-compose.yml test)


Put a tarball of upgraded moby binaries on every node:
    # ON LOCAL MACHINE:
    #  * build the moby binaries
    #    (can get/upgrade this binary by some other means if desired;
    #    for example by debian packages.  If so, adjust upgrade steps
    #    below.)
    $ git clone https://github.com/moby/moby
    $ cd moby
    $ make

    #  * Create a tarball of binary images
    $ cd bundles/binary-daemon/
    $ tar -h -zcvf /tmp/engine-binaries.tgz docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-init docker-proxy docker-runc

    #  * Copy the tarball to the nodes in preparation for upgrade
    #    + get the node IPs
    $ testkit node ls
    #    + do this for each node IP address
    $ scp -i ~/.testkit/testkit.pem  /tmp/engine-binaries.tgz docker@A.B.C.D:


Upgrading a manager:
    # ON ANY MANAGER:
    #  * drain containers from the manager
    $ docker node update --availability drain $(docker node ls | grep NODENAME | awk '{print $1}')

    # ON THE MANAGER TO UPGRADE:
    #  * verify that containers have all stopped
    $ docker container ls 

    #  *** Steps from here could differ by OS as needed. ***
    #  *** This is just the procedure that I used. ***

    #  * stop the docker service
    $ sudo service docker stop
    $ cd /usr/bin/

    #  * backup the old binaries
    $ tar zcvf /home/docker/old-engine-binaries.tgz docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-init docker-proxy docker-runc

    #  * install the new ones
    $ sudo tar zxvf /home/docker/engine-binaries.tgz

    #  * restart the service
    $ sudo service docker start


One must upgrade *all* managers before re-activating them.  After upgrading them all,
reactivate them to receive workloads:
    # ON ANY MANAGER:
    #  * do this for each of the manager node names
    $ docker node update --availability active $(docker node ls | grep NODENAME | awk '{print $1}')


Upgrading the nodes:
    # Follow the same upgrade procedure as a manager as above.   But there
    # is no need to drain them *all* before restarting them.  One can make them
    # active as soon as they are upgraded.


Check for connectivity failures:
    # on local machine:
    #   * verify that output is in /var/lib/docker/volumes/test_cliout/_data/client.log
    #     Look for: "Mountpoint": "/var/lib/docker/volumes/test_cliout/_data",
    #     (if not, adjust path for second command)
    $ testkit machine ssh tk1706-ubuntu-0 docker volume inspect test_cliout

    #   * cat all the output logs to see if there were any "Connectivity error:"s
    $ for i in 0 1 2 3 4 ; do testkit machine ssh tk1706-ubuntu-$i sudo cat /var/lib/docker/volumes/test_cliout/_data/client.log ; done



Potention Errors Encountered When Failing to Follow the Procedure
======================

Error seen if activating a manager before all the managers are upgraded:

    $ docker@tk1706-ubuntu-0:~$ docker service ps test_service
    ID                  NAME                                         IMAGE               NODE                DESIRED STATE       CURRENT STATE                 ERROR                              PORTS
    134tseerb5ay        test_service.rflm00eupnjjkrpt9ot2l93eh       nginx:latest        tk1706-ubuntu-0     Shutdown            Rejected about a minute ago   "node is missing network attac…"   
    tuddp1ycbf38         \_ test_service.rflm00eupnjjkrpt9ot2l93eh   nginx:latest        tk1706-ubuntu-0     Shutdown            Rejected about a minute ago   "node is missing network attac…"   
    ...

    $ docker@tk1706-ubuntu-0:~$ docker inspect 134tseerb5ay
    [
    ...
            "Status": {
                "Timestamp": "2018-08-23T21:18:24.469418288Z",
                "State": "rejected",
                "Message": "preparing",
                "Err": "node is missing network attachments, ip addresses may be exhausted",
                "ContainerStatus": {
                    "ContainerID": "",
                    "PID": 0,
                    "ExitCode": 0
                },
                "PortStatus": {}
            },
    ...
    ]


