# SAND

[![Build Status](https://travis-ci.org/dunkyp/sand.svg?branch=master)](https://travis-ci.org/dunkyp/sand)

## Scanner Access Now D

SAND provides a D interface to the SANE (Scanner Access Now Easy) C API. The interface is designed to be easy to read and safe to use.

```d
// Initialise sane interface
auto sane = new Sane();
    
// Find all devices
auto devices = sane.devices();
    
// List all options for a device
if(devices.length) {
    auto options = devices[0].options;
    foreach(option; options) {
        writeln(option);
    }
}
```

To test the code enable the "test" driver in /etc/sane.d/dll.conf (or system equivelent)

