Scripts for creating KVM nodes and commissioning them in MAAS.

Assuming you have a MAAS profile named `maas` and a virsh network
named `maas-net` you can add and remove nodes as follows:

```
$ ./add-node node1 maas-net maas
$ ./remove-node node1 maas-net maas
```
