PWD=$(CURDIR)
HOSTNAME := $(shell hostname -s)
ifeq ("$(TARGET)", "Mega2560")
ARDUINO_FQBN:=mega:cpu=atmega2560
UPLOAD_DEVICE:=atmega2560
BAUDRATE:=115200
endif
ifeq ("$(TARGET)", "ProMini")
ARDUINO_FQBN:=pro:cpu=16MHzatmega328
UPLOAD_DEVICE:=atmega328p
BAUDRATE:=57600
endif
HOSTPROPS := $(shell find * -depth -maxdepth 0 -name $(HOSTNAME).mk -type f)
ARDUINO_FQBN := $(if $(ARDUINO_FQBN),$(ARDUINO_FQBN),mega:cpu=atmega2560)
UPLOAD_DEVICE := $(if $(UPLOAD_DEVICE),$(UPLOAD_DEVICE),atmega2560)
BAUDRATE := $(if $(BAUDRATE),$(BAUDRATE),115200)
SKETCH := $(if $(SKETCH),$(SKETCH),$(notdir $(CURDIR)))
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
ARDUINO_ROOT=/Applications/Arduino.app/Contents/Java
else
ARDUINO_ROOT=/usr/share/arduino
endif
AVRDUDE_OPTS=
ifeq ($(UPLOAD_DEVICE),atmega2560)
AVRDUDE_OPTS+=-cwiring
endif
ARDUINO_BUILDER=$(ARDUINO_ROOT)/arduino-builder
ARDUINO_HARDWARE=$(ARDUINO_ROOT)/hardware
ARDUINO_TOOLS=$(ARDUINO_ROOT)/hardware/tools
BUILDER_TOOLS=$(ARDUINO_ROOT)/tools-builder
AVRDUDE=$(ARDUINO_TOOLS)/avr/bin/avrdude -C $(ARDUINO_TOOLS)/avr/etc/avrdude.conf
AVRSIM=simavr
SYSTEM_LIBRARIES=$(ARDUINO_ROOT)/libraries
PROJECT_LIBRARIES=../libraries
GITHUB_LIBPATH=$(PROJECT_LIBRARIES)/github.com
ENSURE_DIR := $(shell mkdir -p $(GITHUB_LIBPATH))
ifneq ("$(GITHUB_REPOS)","")
ENSURE_DIR := $(shell cd $(GITHUB_LIBPATH) && mkdir -p $(GITHUB_REPOS))
endif
GITHUB_EMPTYDIRS+=$(sort $(shell cd $(GITHUB_LIBPATH) && find * -depth -maxdepth 2 -type d -empty 2> /dev/null))
GITHUB_POPULATEDIRS=$(sort $(shell cd $(GITHUB_LIBPATH) && find * -depth -mindepth 1 -maxdepth 1 -type d -not -empty 2> /dev/null))
GITHUB_DIRS=$(shell cd $(GITHUB_LIBPATH) && find * -depth -maxdepth 0 -type d 2> /dev/null )
GITHUB_LIBRARIES:=$(addprefix -libraries $(GITHUB_LIBPATH)/,$(GITHUB_DIRS))
ARDUINO_OPTS=
ifeq ("$(VERBOSE)","1")
ARDUINO_OPTS += -verbose
AVRDUDE_OPTS += -v
else
AVRDUDE_OPTS += -q
endif
ifeq ("$(SILENT)","1")
ARDUINO_OPTS += -quiet
AVRDUDE_OPTS += -q
endif
BUILDER_CMD=$(ARDUINO_BUILDER) -hardware $(ARDUINO_HARDWARE) -tools $(ARDUINO_TOOLS) -tools $(BUILDER_TOOLS) -libraries $(SYSTEM_LIBRARIES) -libraries $(PROJECT_LIBRARIES) $(GITHUB_LIBRARIES) -fqbn arduino:avr:$(ARDUINO_FQBN) $(ARDUINO_OPTS) 

# Check to see if we have a host specific override file for PORT variable
ifneq ("$(HOSTPROPS)", "")
include $(HOSTPROPS)
endif

AVRDUDECMD=$(AVRDUDE)
ifneq ("$(UPLOAD_HOSTS)", "")
ifeq ($(filter $(HOSTNAME),$(UPLOAD_HOSTS)),)
AVRDUDECMD = @echo "\nSketch upload disabled. Uploading only allowed on: $(UPLOAD_HOSTS)\n\n   $(AVRDUDE)"
endif
endif

all: build

github_clone:
	@for dir in $(GITHUB_EMPTYDIRS) ; do \
		echo Cloning : https://github.com/$$dir ; \
		git clone https://github.com/$$dir $(GITHUB_LIBPATH)/$$dir ; \
	done

github_pull:
	@for dir in $(GITHUB_POPULATEDIRS) ; do \
		echo Refresh : $(GITHUB_LIBPATH)/$$dir ; \
		cd $(GITHUB_LIBPATH)/$$dir && git pull ; \
	done

%.ino.cpp.o : %.ino.cpp
	@mkdir -p .build
	@$(BUILDER_CMD) -build-path $(PWD)/.build $(SKETCH).ino

-include $(PWD)/.build/sketch/$(SKETCH).ino.cpp.d

.build/$(SKETCH).ino.hex: $(SKETCH).ino $(PWD)/.build/sketch/$(SKETCH).ino.cpp.o
	@mkdir -p .build
	@$(BUILDER_CMD) -build-path $(PWD)/.build $(SKETCH).ino

$(PWD)/.build/sketch/$(SKETCH).ino.cpp.d:
	@mkdir -p .build
	@$(BUILDER_CMD) -build-path $(PWD)/.build $(SKETCH).ino

build: github_clone $(PWD)/.build/sketch/$(SKETCH).ino.cpp.d .build/$(SKETCH).ino.hex

upload:
	@echo "\nUploading on $(HOSTNAME)"
	$(AVRDUDECMD) -p$(UPLOAD_DEVICE) -carduino $(AVRDUDE_OPTS) -P$(PORT) -b$(BAUDRATE) -D -U flash:w:.build/$(SKETCH).ino.hex:i
	@echo

run:
	$(AVRSIM) -m $(UPLOAD_DEVICE) .build/$(SKETCH).ino.elf

debug:
	@echo Start avr-gdb process:
	@echo $(ARDUINO_TOOLS)/avr/bin/avr-gdb $(PWD)/.build/$(SKETCH).ino.elf
	@echo target remote localhost:1234
	$(AVRSIM) -m $(UPLOAD_DEVICE) -g .build/$(SKETCH).ino.elf

clean:
	@rm -rf $(PWD)/.build
