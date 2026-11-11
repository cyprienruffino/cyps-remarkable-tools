// The metadata xovi reads from every extension, in the ".xovi" section. It's
// what xovi's xovigen.py generates for an extension with no imports, exports
// or hooks; see https://github.com/asivery/xovi.
struct XoViEnvironment;
struct XoviMetadataEntry;

extern "C" {

__attribute__((section(".xovi"))) const char *LINKTABLENAMES = "\0";
__attribute__((section(".xovi"))) const void *LINKTABLEVALUES[] = { (void *) 0 };
__attribute__((section(".xovi"))) const struct XoViEnvironment *Environment = 0;
// 0.3.0, as (major << 16) | (minor << 8) | patch
__attribute__((section(".xovi"))) int EXTENSIONVERSION = 0x000300;

__attribute__((section(".xovi_info"))) const char __XOVIMETADATANAMES[] = "";
__attribute__((section(".xovi"))) const struct XoviMetadataEntry **METADATAVALUES[] = {
    (const struct XoviMetadataEntry **) 0, (const struct XoviMetadataEntry **) 1
};

void _xovi_depconstruct() {}

}
