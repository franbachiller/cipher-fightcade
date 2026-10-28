// Desensambla N instrucciones desde una dirección (offset en bytes de la ROM de programa de UMK3, base 0) y las
// imprime. Uso (analyzeHeadless): -postScript DisasmAt.java <direccion_hex> <cantidad>
// Dirección de CPU (bit) -> offset de Ghidra: (bit - 0xFF800000) / 8.
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;

public class DisasmAt extends GhidraScript {
	@Override
	public void run() throws Exception {
		String[] args = getScriptArgs();
		long start = Long.parseLong(args[0].replace("0x", ""), 16);
		int count = Integer.parseInt(args[1]);
		Address a = toAddr(start);
		DisassembleCommand cmd = new DisassembleCommand(new AddressSet(a, toAddr(start + count * 8L)), null, true);
		cmd.applyTo(currentProgram, monitor);
		Instruction ins = getInstructionAt(a);
		if (ins == null) ins = getInstructionAfter(a);
		for (int i = 0; i < count && ins != null; i++) {
			long off = ins.getAddress().getOffset();
			println(String.format("%06X  bit=%08X  %-8s %s", off, 0xFF800000L + off * 8, bytes(ins), ins.toString()));
			ins = ins.getNext();
		}
	}

	private String bytes(Instruction ins) throws Exception {
		StringBuilder sb = new StringBuilder();
		for (byte b : ins.getBytes()) sb.append(String.format("%02X", b));
		return sb.toString();
	}
}
