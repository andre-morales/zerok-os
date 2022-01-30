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
	static final Map<String, Integer> VARIABLES_TYPES_SIZES = new HashMap<>();
	
	static {
		VARIABLES_TYPES_SIZES.put("void", 0);
		VARIABLES_TYPES_SIZES.put("byte", 1);
		VARIABLES_TYPES_SIZES.put("bool", 1);
		VARIABLES_TYPES_SIZES.put("char", 1);
		VARIABLES_TYPES_SIZES.put("short", 2);
		VARIABLES_TYPES_SIZES.put("word", 2);
		VARIABLES_TYPES_SIZES.put("int", 4);
		VARIABLES_TYPES_SIZES.put("long", 8);

		VARIABLES_TYPES_SIZES.put("byte*", 2);
		VARIABLES_TYPES_SIZES.put("char*", 2);
	}
	
	public Map<String, String> defines;     // Command line defines.
	
	Map<String, String> definedPairs;       // #define statements plus command line defines.
	List<String> constants;                 // Constants defined with ."" (read-only data)
	List<Pair<String, Integer>> globalVars; // Global variables (data)	
	LinkedHashMap<String, Integer> stackVars;         // Stack variables
	int currentStackSize = 0;
	int inputLineIndex;
	
	boolean onMultiLineComment = false;
	
	public Transpiler(){
		defines = new HashMap<>();
		definedPairs = new HashMap<>();
		constants = new ArrayList<>();
		globalVars = new ArrayList<>();
		stackVars = new LinkedHashMap<>();
	}
	
	public void transpile(File inputFile, File outputFile){
		constants.clear();
		definedPairs.clear();
		definedPairs.putAll(defines);
		inputLineIndex = 0;
		
		boolean foundDataSection = false;
		boolean foundRODataSection = false;
		
		Writer out;

		var inputPath = inputFile.toPath();
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
					Path filePath;
					if(str.startsWith("<") && str.endsWith(">")){
						filePath = new File(str.substring(1, str.indexOf(">"))).toPath();
					} else {
						filePath = inputPath.resolveSibling(str);
					}
					lineBuffer.addAll(li + 1, Files.readAllLines(filePath));
				} else if (tline.startsWith("#define ")) {
					var def = Str.remainingAfter(line, "#define ").split(" ", 2);
					definedPairs.put(def[0], def[1]);
				} else if (tline.startsWith("#if ")) {
					var def = Str.remainingAfter(line, "#if ");
					ifBlock = true;
					ifBlockTrue = "1".equals(definedPairs.get(def));
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

					for (var variable : globalVars) {
						int size = variable.value;
						out.write("\t" + variable.key + ": ");

						if(size == 0){
							out.write("\n");
							continue;
						}
						out.write("times " + size + " db 0\n");
					}
				} else if (tline.startsWith("var ")) {
					var field = Str.remainingAfter(tline, "var ");
					var pair = getVariable(field);
					globalVars.add(pair);

				} else if (tline.startsWith("lvar ")) {
					var field = Str.remainingAfter(tline, "var ");
					reserveStackVar(field);
				} else if(tline.startsWith("_clstack()")){
					stackVars.clear();
					currentStackSize = 0;
				} else {
					var statements = splitStatements(line);

					for (String stat : statements) {
						if (!stat.trim().startsWith(";")) {
							stat = processStatement(stat);
						}

						out.write(stat);
						out.write('\n');
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

	/**
	 * Processes a line of code and turns it into multiple ordered statements. 
	 * This function also handle folding brackets. */
	List<String> splitStatements(String str) {
		var statements = new ArrayList<String>();

		var onQuotes = 0; // 0 = Not inside quotes, 1 = Inside single quotes, 2 = Inside double quotes.
		var onColonComment = false;
		var statementBuffer = new StringBuilder();
		
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
	
	String processStatement(String stat) {
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
				var varname = Str.untilFirstMatch(stat, i + 1, " ", ",");
				if(varname.equals("stacksize")){
					statementBuffer.append(currentStackSize);
					i += varname.length();
					continue;
				} else {
					var stackOff = stackVars.get(varname);
					if(stackOff != null){
						var stackStr = "[bp - " + stackOff + "]";
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
		pair.key = sp[1]; // Variable name
		
		String type = sp[0].trim();
		int iq = type.indexOf("[");
		if(iq > 0){		
			var arrayType = type.substring(0, iq);
			var arraySize = type.substring(iq + 1, type.indexOf("]"));
			pair.value = VARIABLES_TYPES_SIZES.get(arrayType) * Integer.parseInt(arraySize);
		} else {
			pair.value = VARIABLES_TYPES_SIZES.get(type);
		}
		if(pair.value == null) throw new CASMException("Unknown variable type " + type);
		return pair;	
	}
	
	public void reserveStackVar(String stat){
		var pair = getVariable(stat);
		currentStackSize += pair.value;
		stackVars.put(pair.key, currentStackSize);
	}
}
