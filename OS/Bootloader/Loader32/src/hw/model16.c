#include "model16.h"

uint16_t NO_INLINE NEAR_TEXT call_far16(far_ptr16 fn, uint16_t* args, size_t n) {
	uint32_t fnAddress = fn.offset;
	uint32_t fnSegment = fn.segment;

	size_t argsSize = n * 2;
	uint16_t returnCode;

	__asm volatile (
		// Allocate space for the arguments
		"sub esp, eax					\n\t"

		// ECX is already set with how many args
		"mov edi, esp					\n\t"
		"rep movsw						\n\t"

		// Placing 16-bit return code to here
		"pushw cs						\n\t"
		"pushw OFFSET FLAT:.ending		\n\t"

		// Pushing 32 bit far call
		"pushd %[segment]				\n\t"
		"pushd %[addr]					\n\t"
		"retf							\n\t"

		// Clean stack
		".ending:						\n\t"
		"mov esp, edi					\n\t"

			// Outputs
			: "=a" (returnCode) // AX will contain the function return code

			// Inputs
			: "S" (args),	    // ESI points to Args
			  "a" (argsSize),   // EAX is args size in bytes
			  "c" (n),		    // ECX is how many args

			  [addr]	"g" (fnAddress),
			  [segment] "g" (fnSegment)

			// Clobbers
			: "memory", "edi"
	);

	return returnCode;
}
