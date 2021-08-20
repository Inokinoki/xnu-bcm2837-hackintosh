## Why We need KDK?

In `makedefs/MakeInc.def`,

```
# Link opensource binary library
ifneq ($(filter T8020 T8101 T8020 T8101,$(CURRENT_MACHINE_CONFIG)),)
	LDFLAGS_KERNEL_ONLY += -rdynamic -Wl,-force_load,$(KDKROOT)/System/Library/KernelSupport/lib$(CURRENT_MACHINE_CONFIG).os.$(CURRENT_KERNEL_CONFIG).a
endif
```

The make file indicates some open source libraries to dynamic link :)
