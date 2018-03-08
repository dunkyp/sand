module sane.saned;

import sane.sane;
import std.exception : enforce;
import std.algorithm.iteration;
import std.conv, std.range, std.variant;

// A somewhat sane interface to sane
class Sane {
    int versionMajor, versionMinor, versionBuild;
    Device[] m_devices;

    this() {
    }

    ~this() {
        sane_exit();
    }

    void init() {
        int api_version;
        auto status = sane_init(&api_version, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        SANE_VERSION_CODE(versionMajor, versionMinor, versionBuild);
    }

    auto devices(bool force=false) {
    	if(!m_devices.length || force) {
           SANE_Device** device_list;
           auto status = sane_get_devices(&device_list, true);
           auto size = 0;
           while(*(device_list + size))
               size++;
            m_devices =  device_list[0 .. size].map!(device => new Device(device)).array;
	}
	return m_devices;
    }
}

class Device {
    string name;
    string vendor;
    string model;
    string type;
    SANE_Device* device;
    private Option[] m_options;
    private SANE_Handle handle;
    private bool open;

    this(SANE_Device* device) {
        name = to!string((*device).name);
        vendor = to!string((*device).vendor);
        model = to!string((*device).model);
        type = to!string((*device).type);
        this.device = device;
        sane_open(device.name, &handle);
    }
    
    @property auto options() {
        if(!open) {
            populateOptions();
            open = true;
        }
        return m_options;
    }

    private void populateOptions() {
        auto size = 0;
        while(sane_get_option_descriptor(handle, size))
            size++;
        m_options = iota(size).map!(i => new Option(handle, sane_get_option_descriptor(handle, i), i)).array;
    }
}

class Option {
    const SANE_Option_Descriptor* descriptor;
    int number;
    const string name;
    const string title;
    const string description;
    private SANE_Handle handle;

    this(SANE_Handle handle, const SANE_Option_Descriptor* descriptor, int number) {
        this.descriptor = descriptor;
        this.number = number;
        name = to!string((*descriptor).name);
        title = to!string((*descriptor).title);
        description = to!string((*descriptor).desc);
        this.handle = handle;
    }

    @property auto value() {
        sane_get_option_descriptor(handle, number);
        int value;
        auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_GET_VALUE, &value, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        return value;
    }

    @property void value(int v) {
        sane_get_option_descriptor(handle, number);
        auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, &v, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
    }
}

unittest {
    import std.stdio;
    auto s = new Sane();
    s.init();
    auto devices = s.devices();
    assert(devices[0].options[3].value == 8);
    devices[0].options[3].value = 16;
    assert(devices[0].options[3].value == 16);
}
