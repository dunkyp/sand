module app;

import sand;
import std.stdio;

void main() {
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
}
