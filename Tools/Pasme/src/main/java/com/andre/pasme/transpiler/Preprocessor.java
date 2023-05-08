package com.andre.pasme.transpiler;

import com.andre.pasme.PasmeCLI;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.LineNumberReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author Andre
 */
public class Preprocessor {
	enum IFBlockState {
		OUTSIDE, FALSE, TRUE
	}
	
	public static List<Line> readAllLines(File input) throws IOException {
		var lines = new ArrayList<Line>();
		
		var r = new LineNumberReader(new FileReader(input));
			
		String str;
		while ((str = r.readLine()) != null) {
			int n = r.getLineNumber();
			lines.add(new Line(str, n));
		}
		
		return lines;
	}
	
	public static List<Line> pass(Transpiler tr, List<Line> lines) {
		var emit = new ArrayList<Line>();
		emit.add(new Line("; -- PASME Version " + PasmeCLI.VERSION_STR, 0));
		
		var ifBlockState = IFBlockState.OUTSIDE;

		for (int i = 0; i < lines.size(); i++) {
			var line = lines.get(i);
			var str = line.content;
			var strTr = str.trim();
			var lineN = line.number;

			try {
				// Check if IF block has ended.
				if (strTr.startsWith("#endif")) {
					if (ifBlockState == IFBlockState.OUTSIDE) {
						throw new TranspilerException("LINE " + lineN + ": #endif found but no #if statement before it.");
					}
					ifBlockState = IFBlockState.OUTSIDE;
				}

				// Flip state of IF block if necessary
				if (strTr.startsWith("#else")) {
					if (ifBlockState == IFBlockState.OUTSIDE) {
						throw new TranspilerException("LINE " + lineN + ": #else found but no #if statement before it.");
					}

					if (ifBlockState == IFBlockState.TRUE) ifBlockState = IFBlockState.FALSE;
					else ifBlockState = IFBlockState.TRUE;
					continue;
				}

				// Ignore any lines while inside an IF block that has evaluated to false.
				if (ifBlockState == IFBlockState.FALSE) continue;

				// If its not a preprocessor statement, check if it contains a preprocessor value.
				if (!strTr.startsWith("#")) {
					emit.add(line);

					var bs = str.indexOf("$#");
					if (bs == -1) continue;			

					var es = str.indexOf("#", bs + 2);
					if (es == -1) continue;

					var key = str.substring(bs + 2, es);
					var value = tr.definedConstants.get(key);
					if (value == null) continue;

					line.content = str.replace(str.substring(bs, es+1), value);
					continue;
				}

				if (strTr.startsWith("#define ")) {
					var def = Str.remainingAfter(str, "#define ").split(" ", 2);
					tr.definedConstants.put(def[0], def[1]);
					continue;
				}

				if (strTr.startsWith("#if ")) {
					var def = Str.remainingAfter(str, "#if ");
					var boolResult = "1".equals(tr.definedConstants.get(def));

					if (boolResult) ifBlockState = IFBlockState.TRUE;
					else ifBlockState = IFBlockState.FALSE;
					continue;
				}

				if (strTr.startsWith("#ifdef ")) {
					var def = Str.remainingAfter(str, "#ifdef ");
					var boolResult = tr.definedConstants.get(def) != null;

					if (boolResult) ifBlockState = IFBlockState.TRUE;
					else ifBlockState = IFBlockState.FALSE;
					continue;
				}

				if (strTr.startsWith("#ifndef ")) {
					var def = Str.remainingAfter(str, "#ifndef ");
					var boolResult = tr.definedConstants.get(def) == null;

					if (boolResult) ifBlockState = IFBlockState.TRUE;
					else ifBlockState = IFBlockState.FALSE;
					continue;
				}

				if (strTr.startsWith("#include")) {
					var includeFile = Str.remainingAfter(str, "#include").trim();

					var result = solveInclude(tr, includeFile);
					var includedLines = result.stream()
							.map((String v) -> new Line(v, lineN))
							.toList();

					lines.addAll(i + 1, includedLines);

					line.content = "; -- " + str + "--\n";	
					emit.add(line);
				}
			} catch (Exception ex) {
				throw new TranspilerException("LINE " + lineN + ": Preprocessing fault.", ex);
			}
		}
		return emit;
	}
	
	static List<String> solveInclude(Transpiler tr, String str){
		Path filePath = null;
		if(str.startsWith("<") && str.endsWith(">")){
			var path = Str.untilFirstMatch(str, 1, ">");
			for(String include : tr.includePaths){
				var res = new File(include, path);
				if(res.exists()){
					filePath = res.toPath();
					break;
				}
			}
		} else {
			filePath = tr.inputFile.resolveSibling(str);
		}

		try {
			return Files.readAllLines(filePath);
		} catch(IOException | NullPointerException ex ){
			throw new TranspilerException("Include file '" + str + "' not found.");
		}
	}
}
