#include "model16.h"

int NO_INLINE NEAR_TEXT call_far16(far_ptr16 fn, uint16_t* args, size_t n) {
	uint32_t fnAddress = fn.offset;
	uint32_t fnSegment = fn.segment;

	size_t args_size = n * 2;
	uint16_t returnCode = 0xDE;

	__asm volatile (
		"sub esp, %[args_size]			\n\t"
		"mov edi, esp					\n\t"
		"rep movsw						\n\t"

		// Placing 16-bit return code to here
		"pushw cs						\n\t"
		"pushw OFFSET FLAT:.dummyl		\n\t"

		// Pushing 32 bit far call
		"pushd %[segment]				\n\t"
		"pushd %[addr]					\n\t"
		"retf							\n\t"

		".dummyl:						\n\t"
		"add esp, %[args_size]			\n\t"

			// Outputs
			: "=a" (returnCode) // AX will contain the function return code

			// Inputs
			: "S" (args), // ESI points to Args
			  "c" (argc), // ECX is arg count
			  [args_size] "r" (args_size),
			  [addr]	  "g" (fnAddress),
			  [segment]   "g" (fnSegment)

			// Clobbers
			: "memory", "edi"
	);

	return returnCode;
}
