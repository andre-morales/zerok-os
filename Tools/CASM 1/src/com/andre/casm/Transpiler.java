package com.andre.casm;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 *
 * @author Andre
 */
public class Transpiler {
	static final Map<String, Integer> VARIABLES_SIZES = VariableTypes16.get();
	
	Path inputPath;
	public Map<String, String> defines;     // Command line defines.
	public List<String> includeFolders;     // Paths that might contain files included in the source.
	Map<String, String> definedPairs;       // #define statements plus command line defines.
	List<String> constants;                 // Constants defined with ."" (read-only data)
	List<Pair<String, Integer>> globalVars; // Global variables (data)	
	// Stack variables
	LinkedHashMap<String, Integer> stackVars, stackArgs;         
	int currentStackVarsSize = 0;
	int currentStackArgsSize = 0;
	int inputLineIndex;
	
	boolean onMultiLineComment = false;
	
	public Transpiler(){
		defines = new HashMap<>();
		definedPairs = new HashMap<>();
		constants = new ArrayList<>();
		globalVars = new ArrayList<>();
		stackVars = new LinkedHashMap<>();
		stackArgs = new LinkedHashMap<>();
	}
	
	public void transpile(File inputFile, File outputFile){
		constants.clear();
		definedPairs.clear();
		definedPairs.putAll(defines);
		inputLineIndex = 0;
		
		boolean foundDataSection = false;
		boolean foundRODataSection = false;
		
		Writer out;

		inputPath = inputFile.toPath();
		try {
			out = new FileWriter(outputFile);
			var lineBuffer = Files.readAllLines(inputPath);

			var ifBlock = false;
			var ifBlockTrue = false;
			for (int li = 0; li < lineBuffer.size(); li++) {
				inputLineIndex = li + 1;
				String line = lineBuffer.get(li);
				String tline = line.trim();
				if (ifBlock) {
					if (tline.equals("#endif")) {
						ifBlock = false;
						continue;
					} else if (tline.equals("#else")) {
						ifBlockTrue = !ifBlockTrue;
						continue;
					} else if (!ifBlockTrue) {
						continue;
					}
				}
				
				if (tline.startsWith("#include ")) {
					out.write("; -- " + line + "--\n");
					var str = Str.remainingAfter(line, "#include").trim();
					
					var result = solveInclude(str);
					lineBuffer.addAll(li + 1, result);
				} else if (tline.startsWith("#define ")) {
					var def = Str.remainingAfter(line, "#define ").split(" ", 2);
					definedPairs.put(def[0], def[1]);
				} else if (tline.startsWith("#ifdef ")) {
					var def = Str.remainingAfter(line, "#ifdef ");
					ifBlock = true;
					ifBlockTrue = "1".equals(definedPairs.get(def));
				} else if (tline.startsWith("#ifndef ")) {
					var def = Str.remainingAfter(line, "#ifndef ");
					ifBlock = true;
					ifBlockTrue = !("1".equals(definedPairs.get(def)));
				} else if (tline.startsWith("@rodata:")) {
					foundRODataSection = true;
					out.write(line);
					out.write('\n');

					for (int i = 0; i < constants.size();) {
						var string = constants.get(i++);

						out.write("\t.string" + i + ": db " + getConstantString(string) + "\n");
					}
				} else if (tline.startsWith("@data:")) {
					foundDataSection = true;
					out.write(line);
					out.write('\n');
					dumpDataSection(out);
				} else if (tline.startsWith("var ")) {
					var field = Str.remainingAfter(tline, "var ");
					var pair = getVariable(field);
					globalVars.add(pair);

				} else if (tline.startsWith("farg ")) {
					var field = Str.remainingAfter(tline, "farg ");
					reserveStackArg(field);
				} else if(tline.startsWith("_clstack()")){
					stackVars.clear();
					stackArgs.clear();
					currentStackVarsSize = 0;
					currentStackArgsSize = 0;
				} else {
					var statements = splitStatements(line);

					for (var stat : statements) {
						var tr_stat = stat.trim();
						if (!tr_stat.startsWith(";")) {
							stat = processStatement(stat, tr_stat);
						}
						
						if(stat != null){
							out.write(stat);
							out.write('\n');
						}
					}
				}
			}
			out.close();
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
		
		if(!foundDataSection && globalVars.size() > 0) System.out.println("Warning: Global variables were defined but no @data section defined.");
		if(!foundRODataSection && constants.size() > 0) System.out.println("Warning: Constant strings were defined but no @rodata section defined.");
	}

	void dumpDataSection(Writer out) throws IOException {
		for (var variable : globalVars) {
			int size = variable.value;
			out.write("\t" + variable.key + ": ");

			if(size == 0){
				out.write("\n");
				continue;
			}
			//out.write("times " + size + " db 0\n");
			out.write("resb " + size + "\n");
		}
	}
	
	List<String> solveInclude(String str){
		Path filePath = null;
		if(str.startsWith("<") && str.endsWith(">")){
			var path = Str.untilFirstMatch(str, 1, ">");
			for(String include : includeFolders){
				var res = new File(include, path);
				if(res.exists()){
					filePath = res.toPath();
					break;
				}
			}
		} else {
			filePath = inputPath.resolveSibling(str);
		}

		try {
			return Files.readAllLines(filePath);
		} catch(IOException | NullPointerException ex ){
			throw new CASMException("Include file '" + str + "' not found.");
		}
	}
	
	/**
	 * Processes a line of code and turns it into multiple ordered statements. 
	 * This function also handle folding brackets. */
	List<String> splitStatements(String str) {
		var statements = new ArrayList<String>();

		var onQuotes = 0; // 0 = Not inside quotes, 1 = Inside single quotes, 2 = Inside double quotes.
		var onColonComment = false;
		var statementBuffer = new StringBuilder();
		
		int statementIndex = 0;
		
		var chars = str.toCharArray();
		if(onMultiLineComment){	
			statementBuffer.append(';');
		}
		for (int i = 0; i < chars.length; i++) {
			char c = chars[i];
			char nc = (i < chars.length - 1)?chars[i + 1]:0;
			
			if(onMultiLineComment){
				if(c == '*' && nc == '/'){
					onMultiLineComment = false;
					i++;
				} else {
					statementBuffer.append(c);
				}
			} else if (onColonComment) {
				statementBuffer.append(c);
			} else if (onQuotes == 1) {
				if (c == '\'') {
					onQuotes = 0;
				}

				statementBuffer.append(c);
			} else if (onQuotes == 2) {
				if (c == '"') {
					onQuotes = 0;
				}

				statementBuffer.append(c);
			} else if(c == '/' && nc == '*'){
				onMultiLineComment = true;
				statementBuffer.append(";");
				i++;
			} else {
				switch (c) {
					case '"':
						onQuotes = 2;

						statementBuffer.append(c);
						break;
					case '\'':
						onQuotes = 1;

						statementBuffer.append(c);
						break;
					case '|':
						statements.add(statementBuffer.toString());
						statementBuffer = new StringBuilder();
						onQuotes = 0;
						break;
					case ';':
						onColonComment = true;
						statementBuffer.append(c);
						break;
					default:
						statementBuffer.append(c);
						break;
					case '{':
					case '}':

				}
			}
		}

		statements.add(statementBuffer.toString());
		return statements;
	}
	
	/** Processes the statement given and outputs a result to be placed in the file.
	 *  @param stat pure statement after splitting.
	 *  @param tr_stat trimmed statement to be used for logic. */
	String processStatement(String stat, String tr_stat) {
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
				
			if (c == '.') {
				if (Str.isQuote(nc)) {
					var quotedStr = Str.untilFirstMatch(stat, i + 2, Character.toString(nc));
					var nstr = replaceVars(quotedStr, (name) -> definedPairs.get(name)); 
					constants.add(nc + nstr + nc);
					statementBuffer.append("@rodata.string").append(constants.size());
					i += quotedStr.length() + 2;
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
		return statementBuffer.toString();
	}
	
	/* Given an input, invokes the callback everytime it finds a ${} match.
	The callback must return a string to be placed inside the brackets. */
	static String replaceVars(String input, Function<String, String> callback){
		var result = new StringBuilder();
		var chars = input.toCharArray();
		for(int i = 0; i < chars.length; i++){
			char c = chars[i];
			char nc = (i < chars.length - 1)?chars[i + 1]:0;
			
			if(c == '$' && nc == '{'){
				String varname = Str.untilFirstMatch(input, i + 2, "}");
				result.append(callback.apply(varname));
				i += varname.length() + 2;
				continue;
			}
			result.append(c);
		}
		return result.toString();
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
			pair.value = VARIABLES_SIZES.get(arrayType) * Integer.parseInt(arraySize);
		} else {
			pair.value = VARIABLES_SIZES.get(type);
		}
		if(pair.value == null) throw new CASMException("Unknown variable type " + type);
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
