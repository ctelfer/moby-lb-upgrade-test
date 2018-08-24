# Test Procedure for a Swarm Upgrade Without Service Interruption

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

More generic error lister with tests:

    for i in 0 1 2 3 4
    do
        echo tk1706-ubuntu-$i
        testkit machine ssh tk1706-ubuntu-$i \
            if docker volume inspect test_cliout \> /dev/null 2\>\&1 \; then \
                sudo cat /var/lib/docker/volumes/test_cliout/_data/client.log \; \
            fi
    done



# Potention Errors Encountered When Failing to Follow the Procedure


## Falilures in Node Upgrade Procedure

Error seen if activating a manager before all the managers are upgraded.  This
same error will be seen if the workers are upgraded before the managers:

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


Error seen when leaving a node as active and performing a service stop
and then service start (without upgrade):

    $ docker service ps test_service
    ID                  NAME                                         IMAGE               NODE                DESIRED STATE       CURRENT STATE                 ERROR                              PORTS
    nhk7xvotn8w8        test_service.s356gfdm8y01jtk4t8w9pvjn3       nginx:latest        tk1706-ubuntu-0     Running             Running 59 seconds ago
    er7zhjrz3yfj         \_ test_service.s356gfdm8y01jtk4t8w9pvjn3   nginx:latest        tk1706-ubuntu-0     Shutdown            Rejected about a minute ago   "cannot create a swarm scoped …"
    vxhpsu9msljq         \_ test_service.s356gfdm8y01jtk4t8w9pvjn3   nginx:latest        tk1706-ubuntu-0     Shutdown            Rejected about a minute ago   "cannot create a swarm scoped …"
    s63cina9dbrb        test_service.mrlgc2khq4t6dwwa6td15yjqh       nginx:latest        tk1706-ubuntu-1     Running             Running 3 minutes ago
    hib6okicy3bt        test_service.s356gfdm8y01jtk4t8w9pvjn3       nginx:latest        tk1706-ubuntu-0     Shutdown            Shutdown about a minute ago
    r3d4fwnjt41f        test_service.wx0vsiypkncc33nko29ygqbzk       nginx:latest        tk1706-ubuntu-4     Running             Running 3 minutes ago
    3sf9rw14etsw        test_service.qvic6463l4uog7iw9zid98avs       nginx:latest        tk1706-ubuntu-3     Running             Running 3 minutes ago
    n5roh3wwpllq        test_service.q74h32eah8ewm8e2cn55d1hdm       nginx:latest        tk1706-ubuntu-2     Running             Running 3 minutes ago
    
    $ docker inspect er7zhjrz3yfj
      ...
            "Status": {
                "Timestamp": "2018-08-24T20:26:41.844571484Z",
                "State": "rejected",
                "Message": "preparing",
                "Err": "cannot create a swarm scoped network when swarm is not active",
                "ContainerStatus": {},
                "PortStatus": {}
            },
      ...


## Failure Caused by Address Space Exhaustion

The following signatures can be seen when a network which was near capacity
exceeds capacity following the upgrade.   To trigger this condition one can
do the following:
  * create the test cluster as described above
  * in `exhaust/` run `

        $ (eval "$(testkit machine env tk1706-ubuntu-0)" && docker stack deploy -c docker-compose.yml ex)

    and then

        (eval "$(testkit machine env tk1706-ubuntu-0)" && docker service ls && docker service ps ex_service )

This puts a 24-container service on a 5-node cluster in an overlay network with
`32 - 3 - 1 - 5 = 23` available IP addresses.  The error looks like this:

    ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
    wn3x4lu9cnln        ex_service          replicated          19/24               nginx:latest
    ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE              ERROR               PORTS
    xdevhaoovqew        ex_service.1        nginx:latest        tk1706-ubuntu-1     Running             Preparing 27 seconds ago
    q9fc83to7n8p        ex_service.2        nginx:latest        tk1706-ubuntu-4     Running             Running 25 seconds ago
    p5h3gbxct2cn        ex_service.3        nginx:latest        tk1706-ubuntu-2     Running             Running 25 seconds ago
    fs2380pgiy09        ex_service.4        nginx:latest        tk1706-ubuntu-3     Running             Running 25 seconds ago
    vht1n02bu076        ex_service.5        nginx:latest        tk1706-ubuntu-2     Running             Running 25 seconds ago
    ac4rqb92ln5r        ex_service.6        nginx:latest        tk1706-ubuntu-0     Running             Running 25 seconds ago
    ndopmbh4odwp        ex_service.7        nginx:latest        tk1706-ubuntu-0     Running             Running 25 seconds ago
    15v7de4wh86i        ex_service.8        nginx:latest        tk1706-ubuntu-3     Running             Running 25 seconds ago
    n5qe7b01rims        ex_service.9        nginx:latest        tk1706-ubuntu-3     Running             Running 24 seconds ago
    qwg2kgifx997        ex_service.10       nginx:latest        tk1706-ubuntu-0     Running             Running 25 seconds ago
    i64lee19ia6s        ex_service.11       nginx:latest        tk1706-ubuntu-1     Running             Preparing 27 seconds ago
    mlngcwkok7lv        ex_service.12       nginx:latest        tk1706-ubuntu-4     Running             Running 24 seconds ago
    lvgu2chww41a        ex_service.13       nginx:latest        tk1706-ubuntu-2     Running             Running 25 seconds ago
    v1oris8jvhc1        ex_service.14       nginx:latest        tk1706-ubuntu-1     Running             Preparing 27 seconds ago
    fzadkml9rx6s        ex_service.15       nginx:latest        tk1706-ubuntu-2     Running             Running 25 seconds ago
    ltwiom799rjz        ex_service.16       nginx:latest        tk1706-ubuntu-1     Running             Preparing 27 seconds ago
    rbewma4plt95        ex_service.17       nginx:latest        tk1706-ubuntu-4     Running             Running 25 seconds ago
    vbthfd5pq9hc        ex_service.18       nginx:latest        tk1706-ubuntu-3     Running             Running 25 seconds ago
    58oo545x10ud        ex_service.19       nginx:latest        tk1706-ubuntu-3     Running             Running 24 seconds ago
    iz4dzpalegez        ex_service.20       nginx:latest        tk1706-ubuntu-0     Running             Running 25 seconds ago
    j3u7qsb6uyfe        ex_service.21       nginx:latest        tk1706-ubuntu-2     Running             Running 25 seconds ago
    zjcg1swgcvin        ex_service.22       nginx:latest        tk1706-ubuntu-4     Running             Running 25 seconds ago
    yp8cjae6xh7g        ex_service.23       nginx:latest        tk1706-ubuntu-0     Running             Running 25 seconds ago
    j53nz0hasu0e        ex_service.24       nginx:latest        tk1706-ubuntu-1     Running             Preparing 27 seconds ago

Eventually it can settle to something like this:

    ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
    wn3x4lu9cnln        ex_service          replicated          24/24               nginx:latest
    ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR                              PORTS
    2w6uzqbqtxff        ex_service.1        nginx:latest        tk1706-ubuntu-3     Running             Running 7 minutes ago
    xdevhaoovqew         \_ ex_service.1    nginx:latest        tk1706-ubuntu-1     Shutdown            Rejected 7 minutes ago   "node is missing network attac…"
    q9fc83to7n8p        ex_service.2        nginx:latest        tk1706-ubuntu-4     Running             Running 8 minutes ago
    p5h3gbxct2cn        ex_service.3        nginx:latest        tk1706-ubuntu-2     Running             Running 8 minutes ago
    fs2380pgiy09        ex_service.4        nginx:latest        tk1706-ubuntu-3     Running             Running 8 minutes ago
    vht1n02bu076        ex_service.5        nginx:latest        tk1706-ubuntu-2     Running             Running 8 minutes ago
    ac4rqb92ln5r        ex_service.6        nginx:latest        tk1706-ubuntu-0     Running             Running 8 minutes ago
    ndopmbh4odwp        ex_service.7        nginx:latest        tk1706-ubuntu-0     Running             Running 8 minutes ago
    15v7de4wh86i        ex_service.8        nginx:latest        tk1706-ubuntu-3     Running             Running 8 minutes ago
    n5qe7b01rims        ex_service.9        nginx:latest        tk1706-ubuntu-3     Running             Running 8 minutes ago
    qwg2kgifx997        ex_service.10       nginx:latest        tk1706-ubuntu-0     Running             Running 8 minutes ago
    kah5rzm81dbs        ex_service.11       nginx:latest        tk1706-ubuntu-4     Running             Running 7 minutes ago
    i64lee19ia6s         \_ ex_service.11   nginx:latest        tk1706-ubuntu-1     Shutdown            Rejected 7 minutes ago   "node is missing network attac…"
    mlngcwkok7lv        ex_service.12       nginx:latest        tk1706-ubuntu-4     Running             Running 8 minutes ago
    lvgu2chww41a        ex_service.13       nginx:latest        tk1706-ubuntu-2     Running             Running 8 minutes ago
    pv88mx99lq3x        ex_service.14       nginx:latest        tk1706-ubuntu-0     Running             Running 7 minutes ago
    v1oris8jvhc1         \_ ex_service.14   nginx:latest        tk1706-ubuntu-1     Shutdown            Rejected 7 minutes ago   "node is missing network attac…"
    fzadkml9rx6s        ex_service.15       nginx:latest        tk1706-ubuntu-2     Running             Running 8 minutes ago
    i3o8qmuwf8ls        ex_service.16       nginx:latest        tk1706-ubuntu-2     Running             Running 7 minutes ago
    ltwiom799rjz         \_ ex_service.16   nginx:latest        tk1706-ubuntu-1     Shutdown            Rejected 7 minutes ago   "node is missing network attac…"
    rbewma4plt95        ex_service.17       nginx:latest        tk1706-ubuntu-4     Running             Running 8 minutes ago
    vbthfd5pq9hc        ex_service.18       nginx:latest        tk1706-ubuntu-3     Running             Running 8 minutes ago
    58oo545x10ud        ex_service.19       nginx:latest        tk1706-ubuntu-3     Running             Running 8 minutes ago
    iz4dzpalegez        ex_service.20       nginx:latest        tk1706-ubuntu-0     Running             Running 8 minutes ago
    j3u7qsb6uyfe        ex_service.21       nginx:latest        tk1706-ubuntu-2     Running             Running 8 minutes ago
    zjcg1swgcvin        ex_service.22       nginx:latest        tk1706-ubuntu-4     Running             Running 8 minutes ago
    yp8cjae6xh7g        ex_service.23       nginx:latest        tk1706-ubuntu-0     Running             Running 8 minutes ago
    xb4lzjrkgadk        ex_service.24       nginx:latest        tk1706-ubuntu-4     Running             Running 7 minutes ago
    j53nz0hasu0e         \_ ex_service.24   nginx:latest        tk1706-ubuntu-1     Shutdown            Rejected 7 minutes ago   "node is missing network attac…"

Looking carefully at the output one will notice that there are no Running
tasks on tk1706-ubuntu-1.   This is because the rejected tasks were eventually
able to be assigned to nodes that already had load balancing IP addresses.
This is because with one node without assigned tasks, the total available IP
addresses becomes `32 - 3 - 1 - 4 = 24`.  This is not guaranteed to occur
because whether it does depends upon the order that swarm assigns IP addresses
to nodes and to tasks.

Inspecting one of the failed tasks such as by doing the following on one of the manager nodes:

    $ docker inspect i64lee19ia6s

will yield output like:

    ...
            "Status": {
                "Timestamp": "2018-08-24T21:03:37.885405884Z",
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

(Note that `i64lee19ia6s` was determined from the output of `docker serivce ps ...` above.)
