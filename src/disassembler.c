#include "disassembler.h"

unsigned int disassembler_backend_mask(void) {
  unsigned int result = 0;
#if defined(DISASSEMBLER_ZYDIS)
  result |= 1;
#endif
#if defined(DISASSEMBLER_EXARMO)
  result |= 2;
#endif
#if defined(DISASSEMBLER_CAPSTONE)
  result |= 4;
#endif
  return result;
}

unsigned int disassembler_exarmo_decoder_mask(void) {
  unsigned int result = 0;
#if defined(DISASSEMBLER_EXARMO_ARM)
  result |= 1;
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  result |= 2;
#endif
  return result;
}

unsigned int disassembler_zydis_feature_mask(void) {
  unsigned int result = 0;
#if defined(DISASSEMBLER_ZYDIS_DECODER)
  result |= 1;
#endif
#if defined(DISASSEMBLER_ZYDIS_ENCODER)
  result |= 2;
#endif
#if defined(DISASSEMBLER_ZYDIS_FORMATTER)
  result |= 4;
#endif
  return result;
}
