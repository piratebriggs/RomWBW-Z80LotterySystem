@echo off
setlocal

pushd Binary 
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x00000 0x08000 -o RomWBW0.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x08000 0x10000 -offset -0x08000 -o RomWBW1.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x10000 0x18000 -offset -0x10000 -o RomWBW2.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x18000 0x20000 -offset -0x18000 -o RomWBW3.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x20000 0x28000 -offset -0x20000 -o RomWBW4.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x28000 0x30000 -offset -0x28000 -o RomWBW5.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x30000 0x38000 -offset -0x30000 -o RomWBW6.hex -Intel -Output_Block_Size=16 -address-length=2
"C:\Program Files\srecord\bin\srec_cat.exe" LOT_std.rom -Binary -crop 0x38000 0x40000 -offset -0x38000 -o RomWBW7.hex -Intel -Output_Block_Size=16 -address-length=2
popd

