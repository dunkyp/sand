module sand.sane;
/* sane - Scanner Access Now Easy.
   Copyright (C) 1997-1999 David Mosberger-Tang and Andreas Beck
   This file is part of the SANE package.

   This file is in the public domain.  You may use and modify it as
   you see fit, as long as this copyright message is included and
   that there is an indication as to what modifications have been
   made (if any).

   SANE is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.

   This file declares SANE application interface.  See the SANE
   standard for a detailed explanation of the interface.  */

extern (C):

/*
 * SANE types and defines
 */

enum SANE_CURRENT_MAJOR = 1;
enum SANE_CURRENT_MINOR = 0;

extern (D) auto SANE_VERSION_CODE(T0, T1, T2)(auto ref T0 major, auto ref T1 minor, auto ref T2 build)
{
    return ((cast(SANE_Word) major & 0xff) << 24) | ((cast(SANE_Word) minor & 0xff) << 16) | ((cast(SANE_Word) build & 0xffff) << 0);
}

extern (D) auto SANE_VERSION_MAJOR(T)(auto ref T code)
{
    return ((cast(SANE_Word) code) >> 24) & 0xff;
}

extern (D) auto SANE_VERSION_MINOR(T)(auto ref T code)
{
    return ((cast(SANE_Word) code) >> 16) & 0xff;
}

extern (D) auto SANE_VERSION_BUILD(T)(auto ref T code)
{
    return ((cast(SANE_Word) code) >> 0) & 0xffff;
}

enum SANE_FALSE = 0;
enum SANE_TRUE = 1;

alias SANE_Byte = ubyte;
alias SANE_Word = int;
alias SANE_Bool = int;
alias SANE_Int = int;
alias SANE_Char = char;
alias SANE_String = char*;
alias SANE_String_Const = const(char)*;
alias SANE_Handle = void*;
alias SANE_Fixed = int;

enum SANE_FIXED_SCALE_SHIFT = 16;

extern (D) auto SANE_FIX(T)(auto ref T v)
{
    return cast(SANE_Word) v * (1 << SANE_FIXED_SCALE_SHIFT);
}

extern (D) auto SANE_UNFIX(T)(auto ref T v)
{
    return cast(double) v / (1 << SANE_FIXED_SCALE_SHIFT);
}

enum SANE_Status
{
    SANE_STATUS_GOOD = 0, /* everything A-OK */
    SANE_STATUS_UNSUPPORTED = 1, /* operation is not supported */
    SANE_STATUS_CANCELLED = 2, /* operation was cancelled */
    SANE_STATUS_DEVICE_BUSY = 3, /* device is busy; try again later */
    SANE_STATUS_INVAL = 4, /* data is invalid (includes no dev at open) */
    SANE_STATUS_EOF = 5, /* no more data available (end-of-file) */
    SANE_STATUS_JAMMED = 6, /* document feeder jammed */
    SANE_STATUS_NO_DOCS = 7, /* document feeder out of documents */
    SANE_STATUS_COVER_OPEN = 8, /* scanner cover is open */
    SANE_STATUS_IO_ERROR = 9, /* error during device I/O */
    SANE_STATUS_NO_MEM = 10, /* out of memory */
    SANE_STATUS_ACCESS_DENIED = 11 /* access to resource has been denied */
}

/* following are for later sane version, older frontends wont support */

/* lamp not ready, please retry */
/* scanner mechanism locked for transport */

enum SANE_Value_Type
{
    SANE_TYPE_BOOL = 0,
    SANE_TYPE_INT = 1,
    SANE_TYPE_FIXED = 2,
    SANE_TYPE_STRING = 3,
    SANE_TYPE_BUTTON = 4,
    SANE_TYPE_GROUP = 5
}

enum SANE_Unit
{
    SANE_UNIT_NONE = 0, /* the value is unit-less (e.g., # of scans) */
    SANE_UNIT_PIXEL = 1, /* value is number of pixels */
    SANE_UNIT_BIT = 2, /* value is number of bits */
    SANE_UNIT_MM = 3, /* value is millimeters */
    SANE_UNIT_DPI = 4, /* value is resolution in dots/inch */
    SANE_UNIT_PERCENT = 5, /* value is a percentage */
    SANE_UNIT_MICROSECOND = 6 /* value is micro seconds */
}

struct SANE_Device
{
    SANE_String_Const name; /* unique device name */
    SANE_String_Const vendor; /* device vendor string */
    SANE_String_Const model; /* device model name */
    SANE_String_Const type; /* device type (e.g., "flatbed scanner") */
}

enum SANE_CAP_SOFT_SELECT = 1 << 0;
enum SANE_CAP_HARD_SELECT = 1 << 1;
enum SANE_CAP_SOFT_DETECT = 1 << 2;
enum SANE_CAP_EMULATED = 1 << 3;
enum SANE_CAP_AUTOMATIC = 1 << 4;
enum SANE_CAP_INACTIVE = 1 << 5;
enum SANE_CAP_ADVANCED = 1 << 6;

extern (D) auto SANE_OPTION_IS_ACTIVE(T)(auto ref T cap)
{
    return (cap & SANE_CAP_INACTIVE) == 0;
}

extern (D) auto SANE_OPTION_IS_SETTABLE(T)(auto ref T cap)
{
    return (cap & SANE_CAP_SOFT_SELECT) != 0;
}

enum SANE_INFO_INEXACT = 1 << 0;
enum SANE_INFO_RELOAD_OPTIONS = 1 << 1;
enum SANE_INFO_RELOAD_PARAMS = 1 << 2;

enum SANE_Constraint_Type
{
    SANE_CONSTRAINT_NONE = 0,
    SANE_CONSTRAINT_RANGE = 1,
    SANE_CONSTRAINT_WORD_LIST = 2,
    SANE_CONSTRAINT_STRING_LIST = 3
}

struct SANE_Range
{
    SANE_Word min; /* minimum (element) value */
    SANE_Word max; /* maximum (element) value */
    SANE_Word quant; /* quantization value (0 if none) */
}

struct SANE_Option_Descriptor
{
    SANE_String_Const name; /* name of this option (command-line name) */
    SANE_String_Const title; /* title of this option (single-line) */
    SANE_String_Const desc; /* description of this option (multi-line) */
    SANE_Value_Type type; /* how are values interpreted? */
    SANE_Unit unit; /* what is the (physical) unit? */
    SANE_Int size;
    SANE_Int cap; /* capabilities */

    SANE_Constraint_Type constraint_type;

    /* NULL-terminated list */
    /* first element is list-length */
    union _Anonymous_0
    {
        const(SANE_String_Const)* string_list;
        const(SANE_Word)* word_list;
        const(SANE_Range)* range;
    }

    _Anonymous_0 constraint;
}

enum SANE_Action
{
    SANE_ACTION_GET_VALUE = 0,
    SANE_ACTION_SET_VALUE = 1,
    SANE_ACTION_SET_AUTO = 2
}

enum SANE_Frame
{
    SANE_FRAME_GRAY = 0, /* band covering human visual range */
    SANE_FRAME_RGB = 1, /* pixel-interleaved red/green/blue bands */
    SANE_FRAME_RED = 2, /* red band only */
    SANE_FRAME_GREEN = 3, /* green band only */
    SANE_FRAME_BLUE = 4 /* blue band only */
}

/* push remaining types down to match existing backends */
/* these are to be exposed in a later version of SANE */
/* most front-ends will require updates to understand them */

/* backend specific textual data */
/* complete baseline JPEG file */
/* CCITT Group 3 1-D Compressed (MH) */
/* CCITT Group 3 2-D Compressed (MR) */
/* CCITT Group 4 2-D Compressed (MMR) */

/* bare infrared channel */
/* red+green+blue+infrared */
/* gray+infrared */
/* undefined schema */

struct SANE_Parameters
{
    SANE_Frame format;
    SANE_Bool last_frame;
    SANE_Int bytes_per_line;
    SANE_Int pixels_per_line;
    SANE_Int lines;
    SANE_Int depth;
}

struct SANE_Auth_Data;

enum SANE_MAX_USERNAME_LEN = 128;
enum SANE_MAX_PASSWORD_LEN = 128;

alias SANE_Auth_Callback = void function (
    SANE_String_Const resource,
    SANE_Char* username,
    SANE_Char* password);

SANE_Status sane_init (SANE_Int* version_code, SANE_Auth_Callback authorize);
void sane_exit ();
SANE_Status sane_get_devices (
    const(SANE_Device**)* device_list,
    SANE_Bool local_only);
SANE_Status sane_open (SANE_String_Const devicename, SANE_Handle* handle);
void sane_close (SANE_Handle handle);
const(SANE_Option_Descriptor)* sane_get_option_descriptor (
    SANE_Handle handle,
    SANE_Int option);
SANE_Status sane_control_option (
    SANE_Handle handle,
    SANE_Int option,
    SANE_Action action,
    void* value,
    SANE_Int* info);
SANE_Status sane_get_parameters (SANE_Handle handle, SANE_Parameters* params);
SANE_Status sane_start (SANE_Handle handle);
SANE_Status sane_read (
    SANE_Handle handle,
    SANE_Byte* data,
    SANE_Int max_length,
    SANE_Int* length);
void sane_cancel (SANE_Handle handle);
SANE_Status sane_set_io_mode (SANE_Handle handle, SANE_Bool non_blocking);
SANE_Status sane_get_select_fd (SANE_Handle handle, SANE_Int* fd);
SANE_String_Const sane_strstatus (SANE_Status status);

/* sane_h */
