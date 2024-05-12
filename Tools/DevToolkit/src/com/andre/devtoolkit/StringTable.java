package com.andre.devtoolkit;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 *
 * @author Andre
 */
public class StringTable {
	private final int columns;
	private final List<String[]> rows;
	private final String separator = " ";
	private final Alignment[] columnAlignment;
	
	public StringTable(int columns) {
		this.columns = columns;
		rows = new ArrayList<>();
		columnAlignment = new Alignment[columns];
		Arrays.fill(columnAlignment, Alignment.LEFT);
	}
	
	public void addRow(String... row) {
		rows.add(row);
	}
	
	public void setColumnAlignment(int col, Alignment align) {
		columnAlignment[col] = align;
	}
	
	/** Returns the size a column would have if it had no size limits */
	private int[] getExpandedColumnSizes() {
		int[] sizes = new int[columns];
		for (int i = 0; i < columns; i++) {
			int maxSize = 0;
			
			for (String[] row : rows) {
				int length = row[i].length();
				if (length > maxSize) maxSize = length;
			}
			
			sizes[i] = maxSize;
		}
		return sizes;
	}
	
	@Override
	public String toString() {
		int[] sizes = getExpandedColumnSizes();
		
		var builder = new StringBuilder();
		for (int irow = 0; irow < rows.size(); irow++) {
			var row = rows.get(irow);
			
			for (int i = 0; i < columns; i++) {
				var value = row[i];
				int columnSize = sizes[i];
				
				// Calculate spacing around data
				int spacing = columnSize - value.length();
				int leftSpacing = 0;
				int rightSpacing = 0;
				
				switch(columnAlignment[i]) {
					case LEFT -> rightSpacing = spacing;
					case RIGHT -> leftSpacing = spacing;
					case CENTER -> {
						leftSpacing = spacing / 2;
						rightSpacing = spacing - leftSpacing;
					}
				}
				
				builder.append(" ".repeat(leftSpacing));
				
				if (irow == 0) {
					builder.append(ConsoleColors.WHITE_BOLD_BRIGHT);
					builder.append(ConsoleColors.WHITE_UNDERLINED);
					builder.append(value);
					builder.append(ConsoleColors.RESET);
				} else {
					builder.append(value);
				}
				
				builder.append(" ".repeat(rightSpacing));
				builder.append(separator);
			}
			
			builder.append("\n");
		}
		return builder.toString();
	}
	
	public enum Alignment {
		LEFT, CENTER, RIGHT
	}
}
