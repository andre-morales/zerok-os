package com.andre.pasme.transpiler;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The Pasme transpiler itself. Here's an example on how to use it:
 * 
 * <pre>{@code
 * var inputFile = new File("input.pa");
 * var output = new File("assembly.asm");
 * 
 * var tpiler = new Transpiler();
 * tpiler.transpile(inputFile, output);
 * }</pre>
 * <br> Last edit: 29/04/2023
 * 
 * @author André Morales
 * @version 2.0.0
 */
public class Transpiler {
	static final Map<String, Integer> VARIABLES_SIZES = VariableTypes16.get();
	static final String RODATA_SECTION_MARKER = "@rodata:";
	static final String BSS_SECTION_MARKER = "@data:";
	
	/** Command line defines */
	public Map<String, String> defines;   
	
	/** Paths that might contain files included in the source */
	public List<String> includePaths;     
	
	/** All #define statements plus all the command line defines. */
	Map<String, String> definedConstants;       
	
	/** Constants defined with ."" (read-only data) */
	List<String> rodataStrings;    
	boolean undumpedRodataSymbols;
	
	/** Uninitialized BSS variables.
	 * This is a list of the symbol name and its size. */
	List<Pair<String, Integer>> bssSymbols; 
	boolean undumpedBssSymbols;
	
	/* Stack variables and organization */
	LinkedHashMap<String, Integer> stackVars, stackArgs;         
	int currentStackVarsSize = 0;
	int currentStackArgsSize = 0;
	
	/* General state machine stuff */
	Path inputFile;
	boolean onMultiLineComment = false;
	
	public Transpiler(){
		defines = new HashMap<>();
		rodataStrings = new ArrayList<>();
		bssSymbols = new ArrayList<>();
		stackVars = new LinkedHashMap<>();
		stackArgs = new LinkedHashMap<>();
	}
	
	public void transpile(File inputFile, File outputFile){
		this.inputFile = inputFile.toPath();

		rodataStrings.clear();
		definedConstants = new HashMap<>(defines);

		var lines = readLines(inputFile);
		lines = Preprocessor.pass(this, lines);
		
		var outLines = new ArrayList<Line>();
		
		for (int li = 0; li < lines.size(); li++) {
			var line = lines.get(li);
			var str = line.content;
			var tstr = str.trim();

			if (tstr.startsWith(RODATA_SECTION_MARKER)) {
				undumpedRodataSymbols = false;
				
				outLines.add(line);
				dumpSectionROData(line, outLines);
				continue;
			}
			
			if (tstr.startsWith(BSS_SECTION_MARKER)) {
				undumpedBssSymbols = false;
				
				outLines.add(line);
				dumpSectionBSS(line, outLines);
				continue;
			}
			
			var statements = splitAndCleanLine(line);
			
			for (var stat : statements) {
				var result = processStatement(stat);
				if (result != null) {
					outLines.addAll(result);
				}
			}
		}

		if(undumpedBssSymbols) throw new TranspilerException("Global variables were defined but no @data section defined.");
		if(undumpedRodataSymbols) throw new TranspilerException("Constant strings were defined but no @rodata section defined.");
		
		writeLines(outLines, outputFile);
	}
	
	/**
	 * Processes a line of code and turns it into multiple ordered statements. 
	 * This function also handles folding brackets. */
	List<Line> splitAndCleanLine(Line line) {
		var lines = new ArrayList<Line>();

		char onQuotes = 0;
		var statement = new StringBuilder();
	
		if(onMultiLineComment){	
			statement.append(';');
		}
		
		var chars = line.content.toCharArray();
		for (int i = 0; i < chars.length; i++) {
			char c = chars[i];
			char nc = (i < chars.length - 1)?chars[i + 1]:0;
			
			if(onMultiLineComment){
				if(c == '*' && nc == '/'){
					onMultiLineComment = false;
					i++;
				} else {
					statement.append(c);
				}
				continue;
			}
			
			if (onQuotes != 0) {
				if (onQuotes == c) onQuotes = 0;

				statement.append(c);
				continue;
			}
			
			if(c == '/' && nc == '*'){
				onMultiLineComment = true;
				statement.append(";");
				i++;
				continue;
			}
			
			switch (c) {
				// Style brackets: do not emit.
				case '{', '}' -> {}
				
				// Quoted string
				case '\'', '"' -> {
					onQuotes = c;
					statement.append(c);
				}
				
				// Statement splitter: do not emit
				case '|' -> {
					lines.add(new Line(statement.toString(), line.number));
					statement = new StringBuilder();
				}
				
				// Line comment: just append the rest of the line and
				// quit out of the loop
				case ';' -> {
					statement.append(line.content.substring(i));
					i = Integer.MAX_VALUE - 1;
				}
				
				default -> statement.append(c);
			}
		}
		
		lines.add(new Line(statement.toString(), line.number));
		return lines;
	}
	
	List<Line> readLines(File file) {
		try {
			return Preprocessor.readAllLines(file);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	void writeLines(List<Line> lines, File outputFile) {
		try (var out = new FileWriter(outputFile)) {
			for (var line : lines) {
				out.write(line.content);
				if (!line.content.endsWith("\n")) out.write("\n");
			}
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	void dumpSectionROData(Line cause, List<Line> lines) {
		undumpedRodataSymbols = false;
		
		for (int i = 0; i < rodataStrings.size();) {
			var string = rodataStrings.get(i++);
			
			var r = "\t.string" + i + ": db " + getConstantString(string) + "\n";
			lines.add(new Line(r, cause.number));
		}
	}
	
	void dumpSectionBSS(Line cause, List<Line> lines) {
		undumpedBssSymbols = false;
		
		for (var variable : bssSymbols) {
			int size = variable.value;
			
			var r = "\t" + variable.key + ": ";

			if(size == 0){
				r += "\n";
			} else {
				r += "resb " + size + "\n";
			}
			
			lines.add(new Line(r, cause.number));
		}
	}
	
	/** Processes the statement given and outputs a result to be placed in the file.
	 *  @param stat pure statement after splitting.
	 *  @param tr_stat trimmed statement to be used for logic. */
	List<Line> processStatement(Line line) {
		var stat = line.content;
		var tr_stat = line.content.trim();
		
		if (tr_stat.startsWith("var ")) {
			var field = Str.remainingAfter(tr_stat, "var ");
			var pair = getVariable(field);
			bssSymbols.add(pair);
			undumpedBssSymbols = true;
			return null;
		}
		
		if (tr_stat.startsWith("farg ")) {
			var field = Str.remainingAfter(tr_stat, "farg ");
			reserveStackArg(field);
			return null;
		}
		
		if (tr_stat.startsWith("ENTERFN")) {
			var emit = new ArrayList<Line>();
			emit.add(new Line("push bp", line));
			emit.add(new Line("mov bp, sp", line));
			if (currentStackVarsSize > 0) {
				emit.add(new Line("sub sp, " + currentStackVarsSize, line));
			}
			return emit;
		}
		
		if (tr_stat.startsWith("LEAVEFN")) {
			var emit = new ArrayList<Line>();
			emit.add(new Line("mov sp, bp", line));
			emit.add(new Line("pop bp", line));
			if (currentStackArgsSize > 0) {
				emit.add(new Line("ret " + currentStackArgsSize, line));
			} else {
				emit.add(new Line("ret" , line));
			}
			
			stackVars.clear();
			stackArgs.clear();
			currentStackVarsSize = 0;
			currentStackArgsSize = 0;			
			return emit;
		}
		
		if(tr_stat.startsWith("CLSTACK")){
			stackVars.clear();
			stackArgs.clear();
			currentStackVarsSize = 0;
			currentStackArgsSize = 0;
			return null;
		} 
		
		if (tr_stat.startsWith("lvar ")) {
			var field = Str.remainingAfter(stat, "lvar ");
			reserveStackVar(field);
			return null;
		} 
	
		var statementBuffer = new StringBuilder();
		char[] chars = stat.toCharArray();
		
		for (int i = 0; i < chars.length; i++) {
			char c = chars[i];
			char nc = ((i + 1 < chars.length) ? chars[i + 1] : '\0');
			
			// If we hit a comment, just spit the rest of it and quit out of the loop
			if (c == ';') {
				statementBuffer.append(stat.substring(i));
				break;
			}
			
			if (c == '.') {
				if (Str.isQuote(nc)) {
					var quotedStr = Str.untilFirstMatch(stat, i + 2, Character.toString(nc));
					rodataStrings.add(nc + quotedStr + nc);
					statementBuffer.append("@rodata.string").append(rodataStrings.size());
					i += quotedStr.length() + 2;
					undumpedRodataSymbols = true;
					continue;
				}
			} else if (Str.isQuote(c)) {
				var quotedStr = Str.untilFirstMatch(stat, i + 1, Character.toString(c));
				statementBuffer.append(c + quotedStr + c);
				i += quotedStr.length() + 1;
				continue;
			} else if(c == '$'){
				var varname = Str.untilFirstMatch(stat, i + 1, " ", ",", "]", "}").trim();
				if(varname.equals("stack_vars_size")){
					statementBuffer.append(currentStackVarsSize);
					i += varname.length();
					continue;
				} else if(varname.equals("stack_args_size")){
					statementBuffer.append(currentStackArgsSize);
					i += varname.length();
					continue;
				} else {
					var stackVarOff = stackVars.get(varname);
					if(stackVarOff != null){
						var stackStr = "bp - " + stackVarOff;
						statementBuffer.append(stackStr);
						i += varname.length();
						continue;
					}
					
					var stackArgOff = stackArgs.get(varname);
					if(stackArgOff != null){
						var stackStr = "bp + " + stackArgOff;
						statementBuffer.append(stackStr);
						i += varname.length();
						continue;
					}
				}
			}
			statementBuffer.append(c);
		}
		
		line.content = statementBuffer.toString();
		return List.of(line);
	}
			
	static String getConstantString(String str) {
		if (str.startsWith("\"")) {
			str = str
				.replace("\\r", "\", 0Dh, \"")
				.replace("\\n", "\", 0Ah, \"")
				.replace("\\N", "\", 0Dh, 0Ah, \"");
		}
		return str + ", 0";
	}

	public Pair<String, Integer> getVariable(String line){
		var pair = new Pair<String, Integer>();
		var sp = line.split(" ", 2);
		pair.key = sp[1].trim(); // Variable name
		
		String type = sp[0].trim();
		int iq = type.indexOf("[");
		if(iq > 0){		
			var arrayType = type.substring(0, iq);
			var arraySize = type.substring(iq + 1, type.indexOf("]"));
			pair.value = VARIABLES_SIZES.get(arrayType) * Integer.valueOf(arraySize);
		} else {
			pair.value = VARIABLES_SIZES.get(type);
		}
		if(pair.value == null) throw new TranspilerException("Unknown variable type " + type);
		return pair;	
	}
	
	public void reserveStackVar(String stat){
		var pair = getVariable(stat);
		currentStackVarsSize += pair.value;
		stackVars.put(pair.key, currentStackVarsSize);
	}
	
	public void reserveStackArg(String stat){
		var pair = getVariable(stat);
		stackArgs.put(pair.key, 4 + currentStackArgsSize);
		currentStackArgsSize += pair.value;
	}
}