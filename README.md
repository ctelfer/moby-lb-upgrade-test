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

    #  * check that services have successfully migrated
    $ docker service ps test_service
    $ docker service ps test_client

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


Output after cat-ing the voumes the output should look as follows.   The number
of lines may vary depending on how swarm places containers in the overall network.

    Fri Aug 24 15:49:38 UTC 2018: Starting client service
    Fri Aug 24 15:51:15 UTC 2018: Starting client service
    Fri Aug 24 16:01:09 UTC 2018: Starting client service
    Fri Aug 24 15:54:21 UTC 2018: Starting client service
    Fri Aug 24 15:59:26 UTC 2018: Starting client service
    Fri Aug 24 15:55:28 UTC 2018: Starting client service
    Fri Aug 24 15:49:38 UTC 2018: Starting client service

The output of `docker service ps test_client` and
`docker service ps test_serivce` should look similarly uninteresting:

    docker@tk1706-ubuntu-0:~$ docker service ps test_client
    ID                  NAME                IMAGE                                NODE                DESIRED STATE       CURRENT STATE                 ERROR               PORTS
    dsfza4hcu4gp        test_client.1       ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-2     Running             Running 2 minutes ago
    xjnra1dwfttg         \_ test_client.1   ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-3     Shutdown            Shutdown 2 minutes ago
    o58t2inc3tka         \_ test_client.1   ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-2     Shutdown            Shutdown 6 minutes ago
    un3vbh1iv2pb         \_ test_client.1   ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-1     Shutdown            Shutdown 7 minutes ago
    5gp5gbt61sh9         \_ test_client.1   ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-0     Shutdown            Shutdown 11 minutes ago
    ibg27ylftdgv        test_client.2       ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-1     Running             Running about a minute ago
    tnw3gxifz0ef         \_ test_client.2   ctelfer/lb-upgrade-test-cli:latest   tk1706-ubuntu-4     Shutdown            Shutdown about a minute ago
    
    
    docker@tk1706-ubuntu-0:~$ docker service ps test_service
    ID                  NAME                                     IMAGE               NODE                DESIRED STATE       CURRENT STATE                 ERROR               PORTS
    n28ip529ru04        test_service.w232ljdni54ibvlsgewehon99   nginx:latest        tk1706-ubuntu-4     Running             Running 30 seconds ago
    7uffy3trubyq        test_service.z5tqpoosc7akmy1rooonzyqk2   nginx:latest        tk1706-ubuntu-3     Running             Running 2 minutes ago
    qfj700xptc0d        test_service.bkir1i90n88pf3n30ftx32yww   nginx:latest        tk1706-ubuntu-2     Running             Running 5 minutes ago
    d64vq365ehi2        test_service.rgwd7c9f151elfy4io9es7983   nginx:latest        tk1706-ubuntu-1     Running             Running 5 minutes ago
    jnk6579o00si        test_service.t7felwp30mvi4n910z2y3u1cu   nginx:latest        tk1706-ubuntu-0     Running             Running 6 minutes ago
    x1w1vpvlwhru        test_service.w232ljdni54ibvlsgewehon99   nginx:latest        tk1706-ubuntu-4     Shutdown            Shutdown about a minute ago
    rxktf2n2jqbb        test_service.z5tqpoosc7akmy1rooonzyqk2   nginx:latest        tk1706-ubuntu-3     Shutdown            Shutdown 3 minutes ago
    mklb6o6mcyab        test_service.bkir1i90n88pf3n30ftx32yww   nginx:latest        tk1706-ubuntu-2     Shutdown            Shutdown 6 minutes ago
    m4umkff8i5w0        test_service.rgwd7c9f151elfy4io9es7983   nginx:latest        tk1706-ubuntu-1     Shutdown            Shutdown 8 minutes ago
    z59srrwswmv8        test_service.t7felwp30mvi4n910z2y3u1cu   nginx:latest        tk1706-ubuntu-0     Shutdown            Shutdown 11 minutes ago



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
