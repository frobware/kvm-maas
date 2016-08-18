Scripts for creating KVM nodes and commissioning them in MAAS.

Assuming you have a MAAS profile named `maas` and a virsh network
named `maas-net` you can add and remove nodes as follows:

```
$ ./bin/kvm-maas-add-node node1 maas-net maas
$ ./bin/kvm-maas-remove-node node1 maas-net maas
```

These commands will work for MAAS 1.9 and 2.0.
