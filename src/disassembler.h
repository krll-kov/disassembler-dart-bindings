#ifndef DISASSEMBLER_H_
#define DISASSEMBLER_H_

#if defined(_WIN32)
#define DISASSEMBLER_API __declspec(dllexport)
#else
#define DISASSEMBLER_API __attribute__((visibility("default")))
#endif

DISASSEMBLER_API unsigned int disassembler_backend_mask(void);
DISASSEMBLER_API unsigned int disassembler_exarmo_decoder_mask(void);
DISASSEMBLER_API unsigned int disassembler_zydis_feature_mask(void);

#endif
