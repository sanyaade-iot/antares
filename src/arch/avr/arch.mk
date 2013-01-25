include $(ANTARES_DIR)/src/arch/avr/mcu_database.mk
#Set our build goals
BUILDGOALS=$(IMAGENAME).bin $(IMAGENAME).lss $(IMAGENAME).hex $(IMAGENAME).eep \
	$(IMAGENAME).eep.bin

# Do not combine objects into built-in.o
# This screws up things on avr and breaks ANTARES_* macros
# So it's 100% safe to set this to y
LD_NO_COMBINE=y

TARGET_HEXFILE=$(IMAGENAME).hex
TARGET_BINFILE=$(IMAGENAME).bin
TARGET_EEPFILE=$(IMAGENAME).eep
TARGET_EEPFILE=$(IMAGENAME).eep.bin

CFLAGS+= -mmcu=$(MCU) -DF_CPU=$(CONFIG_F_CPU)
ELFFLAGS+= -mmcu=$(MCU) -DF_CPU=$(CONFIG_F_CPU)

#avr-specifik voodoo for hex generation

#ELFFLAGS+=-Wl,--relax,--gc-sections 
#CFLAGS+=-Wl,--relax,--gc-sections 

ifeq ($(CONFIG_AVR_BLDR),y)
ELFFLAGS+=-Wl,--section-start=.text=$(CONFIG_AVR_BLDADDR)
CFLAGS+=-fno-move-loop-invariants -fno-tree-scev-cprop -fno-inline-small-functions -Wl,--section-start=.text=$(CONFIG_AVR_BLDADDR)
endif

ifeq ($(CONFIG_AVR_VFPRINTF_MIN),y)
ELFFLAGS+= -Wl,-u,vfprintf -lprintf_min
endif

ifeq ($(CONFIG_AVR_VFPRINTF_FULL),y)
ELFFLAGS+= -Wl,-u,vfprintf -lprintf_flt -lm
endif


HEX_FLASH_FLAGS = -R .eeprom -R .fuse -R .lock -R .signature
HEX_EEPROM_FLAGS = -j .eeprom
HEX_EEPROM_FLAGS += --set-section-flags=.eeprom="alloc,load"
HEX_EEPROM_FLAGS += --change-section-lma .eeprom=0 --no-change-warnings

FLASHSIZE= $(shell echo $$((`echo -e "\#include <avr/io.h>\nFLASHEND" | avr-cpp -mmcu=$(MCU) | sed '$$!d'` + 1 )))
RAMSTART= $(shell echo $$((`echo -e "\#include <avr/io.h>\nRAMSTART" | avr-cpp -mmcu=$(MCU) | sed '$$!d'`)))
RAMEND=$(shell echo $$((`echo -e "\#include <avr/io.h>\nRAMEND" | avr-cpp -mmcu=$(MCU) | sed '$$!d'` )))
RAMSIZE=$(shell echo $$(($(RAMEND)-$(RAMSTART))))
#No way to get eeprom sizes this way, parse avrdude.conf?


%.hex: %.elf
		$(SILENT_OBJCOPY) $(OBJCOPY) -O ihex $(HEX_FLASH_FLAGS)  $< $@	

%.eep: %.elf
		$(SILENT_OBJCOPY) $(OBJCOPY) $(HEX_EEPROM_FLAGS) -O ihex $< $@ || exit 0

%.eep.bin: %.elf
		$(SILENT_OBJCOPY) $(OBJCOPY) $(HEX_EEPROM_FLAGS) -O binary $< $@ || exit 0


sizecheck:
	$(Q)$(ANTARES_DIR)/scripts/meter "FLASH Usage" \
	`$(SIZE) $(IMAGENAME).elf |grep elf|awk '{print $$1+$$2}'` \
	$(FLASHSIZE);
	$(Q)$(ANTARES_DIR)/scripts/meter "RAM Usage" \
	`$(SIZE) $(IMAGENAME).elf |grep elf|awk '{print $$2+$$3}'` \
	$(RAMSIZE);
	$(Q)echo "Note: Ram usage is only rough minimum estimation (.data + .bss)"
	$(Q) echo "EEPROM data is " \
	`stat $(IMAGENAME).eep.bin -c %s` bytes \
	$(EEPROM_SIZE);

BUILDGOALS+=sizecheck
PHONY+=list-interrupts stm32probe sizecheck
