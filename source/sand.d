import sane;
import std.exception : enforce, assertThrown;
import std.algorithm.iteration, std.string;
import std.conv, std.range, std.utf;
import std.algorithm: canFind;

/** The D interface to SANE */
class Sane {
    int versionMajor, versionMinor, versionBuild;
    Device[] m_devices;

    this() {
        init();
    }

    ~this() {
        sane_exit();
    }

    private void init() {
        int api_version;
        auto status = sane_init(&api_version, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        SANE_VERSION_CODE(versionMajor, versionMinor, versionBuild);
    }

    /**
     * Get list of devices connected to this machine
     * Params:
     *   force = recheck all devices
     */
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

    override string toString() {
        return format("SANE Device: %s - %s", vendor, model);
    }

    /** Get options */
    @property auto options() {
        if(!open) {
            populateOptions();
            open = true;
        }
        return m_options;
    }

    /** Get current scan parameters */
    @property auto parameters() {
        SANE_Parameters p;
        sane_get_parameters(handle, &p);
        return p;
    }

    private void populateOptions() {
        auto size = 0;
        while(sane_get_option_descriptor(handle, size))
            size++;
        m_options = iota(size).map!(i => new Option(handle, i)).array;
    }

    /** 
     * Blocking operation!
     * Returns: A new buffer with image data
     */
    auto readImage() {
        sane_start(handle);
        SANE_Parameters params;
        enforce(sane_get_parameters(handle, &params) == SANE_Status.SANE_STATUS_GOOD);
        auto totalBytes = params.lines * params.bytes_per_line;
        ubyte[] data = new ubyte[totalBytes];
        int length, offset;
        SANE_Status status;
        do {
            status = sane_read(handle, data.ptr, totalBytes, &length);
            offset += length;
        } while (status == SANE_Status.SANE_STATUS_GOOD);
        return data;
    }
}

class Option {
    int number;
    const string name;
    const string title;
    const string description;
    const string unit;
    private SANE_Handle handle;

    this(SANE_Handle handle, int number) {
        this.number = number;
        auto descriptor = sane_get_option_descriptor(handle, number);
        name = to!string((*descriptor).name);
        title = to!string((*descriptor).title);
        description = to!string((*descriptor).desc);
        unit = unitToString(descriptor.unit);
        this.handle = handle;
    }

    override string toString() {
        return format("Option:\nName: %s\nTitle: %s\nDescription: %s\nUnit: %s" ~
                      "\nSettable: %s\nActive: %s", name, title, description, unit, settable(), active());
    }

    private string unitToString(SANE_Unit unit) {
        switch(unit) {
        case SANE_Unit.SANE_UNIT_NONE:
            return "(none)";
        case SANE_Unit.SANE_UNIT_PIXEL:
            return "pixels";
        case SANE_Unit.SANE_UNIT_BIT:
            return "bits";
        case SANE_Unit.SANE_UNIT_MM:
            return "millimetres";
        case SANE_Unit.SANE_UNIT_DPI:
            return "dots per inch";
        case SANE_Unit.SANE_UNIT_PERCENT:
            return "percentage";
        case SANE_Unit.SANE_UNIT_MICROSECOND:
            return "microseconds";
        default:
            assert(0);
        }
    }

    @property bool settable() {
        return SANE_OPTION_IS_SETTABLE(sane_get_option_descriptor(handle, number).cap);
    }

    @property bool active() {
        return SANE_OPTION_IS_ACTIVE(sane_get_option_descriptor(handle, number).cap);
    }

    @property bool group() {
        return sane_get_option_descriptor(handle, number).type == SANE_Value_Type.SANE_TYPE_GROUP;
    }

    @property auto value() {
        sane_get_option_descriptor(handle, number);
        int value;
        auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_GET_VALUE, &value, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        return value;
    }

    /**
     * Set property value
     */
    @property void value(T)(T value) {
        if(!settable())
            throw new Exception("Option is not settable");
        if(!meetsConstraint(value))
            throw new Exception("Value doesn't meet constriant");
        auto descriptor = sane_get_option_descriptor(handle, number);
        static if(is(typeof(value) == string)) {
            auto s = toUTFz!(char*)(value);
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, s, null);
        } else {
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, &value, null);
        }
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
    }

    private bool meetsConstraint(T)(T value) {
        auto descriptor = sane_get_option_descriptor(handle, number);
        switch(descriptor.constraint_type) {            
        case SANE_Constraint_Type.SANE_CONSTRAINT_NONE:
            return true;
        case SANE_Constraint_Type.SANE_CONSTRAINT_RANGE:
            auto range = descriptor.constraint.range;
            if(value < range.min || value > range.max)
                return false;
            if((range.quant * value + range.min) <= range.max)
                return true;
            return false;
        case SANE_Constraint_Type.SANE_CONSTRAINT_WORD_LIST:
            auto count = *descriptor.constraint.word_list;
            auto wordList = descriptor.constraint.word_list[1..count + 1];
            return wordList.canFind(value);
        default:
            throw new Exception("Value doesn't meet constraint");
        }
    }

    private bool meetsConstraint(string value) {
        auto descriptor = sane_get_option_descriptor(handle, number);
        switch(descriptor.constraint_type) {            
        case SANE_Constraint_Type.SANE_CONSTRAINT_STRING_LIST:
            string[] stringList;
            int position = 0;
            while(*(descriptor.constraint.string_list + position)) {
                stringList ~= to!string(*(descriptor.constraint.string_list + position));
                position++;
            }
            return stringList.canFind(value);
        default:
            throw new Exception("Can't enfore constraint");
        }
    }
}

unittest {
    auto s = new Sane();
    auto devices = s.devices();
    devices[0].options[2].value = "Gray";
    assertThrown(devices[0].options[2].value = "Grey");
    assert(devices[0].options[3].value == 8);
    devices[0].options[3].value = 16;
    assert(devices[0].options[3].value == 16);
    assert(devices[0].options[3].settable);
    assert(devices[0].options[3].active);
    devices[0].readImage();
    assertThrown(devices[0].options[0].value = 5);
    assert(devices[0].options[1].group);
    assert(!devices[0].options[2].group);
}
