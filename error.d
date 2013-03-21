
import std.stdio;
import std.string, std.range, std.array, std.uni;

import lexer, util;

abstract class ErrorHandler{
	string source;
	string code;
	int nerrors=0;
	int tabsize=8;
	private string[] _lines;
	@property string[] lines(){
		if(_lines !is null) return _lines;
		return _lines=code.splitLines(); // TODO: implement manually. (this can throw on invalid character sequences)
	}
	void error(string err, Location loc){nerrors++;}   // in{assert(loc.rep);}body
	void note(string note, Location loc)in{assert(loc.rep);}body{};
	this(string s, string c){
		_lines=null;
		source=s;
		code=c;
	}
	/*protected int getLine(string loc){
		auto l=assumeSorted!"a.ptr<=b.ptr"(lines);
		return cast(int)l.lowerBound(loc).length;
	}*/
	protected int getColumn(Location loc){
		int res=0;
		auto l=lines[loc.line-1];
		for(;!l.empty&&l[0]&&l.ptr<loc.rep.ptr; l.popFront()){
			if(l.front=='\t') res=res-res%tabsize+tabsize;
			else res++;
		}
		return res+1;
	}
}
class SimpleErrorHandler: ErrorHandler{
	this(string source,string code){super(source,code);}
	override void error(string err, Location loc){
		stderr.writeln(source,'(',loc.line,"): error: ",err);
	}
}

// TODO: remove code duplication

class VerboseErrorHandler: ErrorHandler{
	this(string source, string code){super(source,code);}
	override void error(string err, Location loc){
		nerrors++;
		if(loc.rep.ptr<lines[loc.line-1].ptr) loc.rep=loc.rep[lines[loc.line-1].ptr-loc.rep.ptr..$];
		auto column=getColumn(loc);
		stderr.writeln(source,':',loc.line,":",column,": ","error: ",err);
		if(loc.rep[0]){
			stderr.writeln(lines[loc.line-1]);
			foreach(i;0..column-1) stderr.write(" ");
			stderr.write("^");
			loc.rep.popFront();
			foreach(x;loc.rep) stderr.write("~");
			stderr.writeln();
		}
	}
}

import terminal;
class FormattingErrorHandler: VerboseErrorHandler{
	this(string source,string code){super(source,code);}
	override void error(string err, Location loc){
		if(isATTy(stderr)){
			nerrors++;
			if(loc.rep.ptr<lines[loc.line-1].ptr) loc.rep=loc.rep[lines[loc.line-1].ptr-loc.rep.ptr..$];
			auto column=getColumn(loc);
			stderr.writeln(BOLD,source,':',loc.line,":",column,": ",RED,"error:",RESET,BOLD," ",err,RESET);
			if(loc.rep[0]){
				stderr.writeln(lines[loc.line-1]);
				foreach(i;0..column-1) stderr.write(" ");
				//stderr.write(CSI~"A",GREEN,";",CSI~"D",CSI~"B");
				stderr.write(BOLD,GREEN,"^");
				loc.rep.popFront();
				foreach(dchar x;loc.rep){if(isNewLine(x)) break; stderr.write("~");}
				stderr.writeln(RESET);
			}
		}else VerboseErrorHandler.error(err,loc);
	}
	override void note(string err, Location loc){
		if(isATTy(stderr)){
			nerrors++;
			if(loc.rep.ptr<lines[loc.line-1].ptr) loc.rep=loc.rep[lines[loc.line-1].ptr-loc.rep.ptr..$];
			auto column=getColumn(loc);
			stderr.writeln(BOLD,source,':',loc.line,":",column,": ",BLACK,"note:",RESET,BOLD," ",err,RESET);
			if(loc.rep[0]){
				stderr.writeln(lines[loc.line-1]);
				foreach(i;0..column-1) stderr.write(" ");
				//stderr.write(CSI~"A",GREEN,";",CSI~"D",CSI~"B");
				stderr.write(BOLD,GREEN,"^");
				loc.rep.popFront();
				foreach(dchar x;loc.rep){if(isNewLine(x)) break; stderr.write("~");}
				stderr.writeln(RESET);
			}
		}else VerboseErrorHandler.note(err,loc);
	}

}
