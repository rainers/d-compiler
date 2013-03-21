
import std.array, std.algorithm, std.range, std.conv, std.string;

import lexer, parser, expression, statement, type, scope_, semantic, visitors, util;

class Declaration: Statement{ // empty declaration if instanced
	STC stc;
	Identifier name;
	this(STC stc,Identifier name){
		this.stc=stc;
		this.name=name;
		sstate = SemState.pre;
	}
	override string toString(){return ";";}

	override @property string kind(){return "declaration";}

	mixin DownCastMethods!(
		VarDecl,
		FunctionDecl,
		// purely semantic nodes
		OverloadableDecl,
		OverloadSet,
		// FwdRef,
		MutableAliasRef,
		ErrorDecl,
	);

	mixin Visitors;
}

class ErrorDecl: Declaration{
	this(){super(STC.init, null); sstate=SemState.error;}
	override ErrorDecl isErrorDecl(){return this;}
	override string toString(){return "__error ;";}

	mixin Visitors;
}

class ModuleDecl: Declaration{
	Expression symbol;
	this(STC stc, Expression sym){symbol=sym; super(stc, null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"module "~symbol.toString()~";";}
}

class ImportBindingsExp: Expression{
	Expression symbol;
	Expression[] bindings;
	this(Expression sym, Expression[] bind){symbol=sym; bindings=bind;}
	override string toString(){return symbol.toString()~": "~join(map!(to!string)(bindings),", ");}
}
class ImportDecl: Declaration{
	Expression[] symbols;
	this(STC stc, Expression[] sym){symbols=sym; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"import "~join(map!(to!string)(symbols),", ")~";";}
}
class EnumDecl: Declaration{
	Expression base;
	Expression[2][] members;
	this(STC stc,Identifier name, Expression base, Expression[2][] mem){this.base=base; members=mem; super(stc,name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"enum"~(name?" "~name.toString():"")~(base?":"~base.toString():"")~
			"{"~join(map!((a){return a[0].toString()~(a[1]?"="~a[1].toString():"");})(members),",")~"}";}
}

abstract class ConditionalDecl: Declaration{
	Statement bdy;
	Statement els;
	this(STC stc,Statement b,Statement e)in{assert(b&&1);}body{bdy=b; els=e; super(stc,null);}
}
class VersionSpecDecl: Declaration{
	Expression spec;
	this(STC stc,Expression s)in{assert(s!is null);}body{spec=s; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"version="~spec.toString()~";";}
}
class VersionDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b, Statement e)in{assert(c!is null);}body{cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"version("~cond.toString()~") "~bdy.toString()~
			(els?(cast(BlockStm)bdy||cast(BlockDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class DebugSpecDecl: Declaration{
	Expression spec;
	this(STC stc,Expression s)in{assert(s!is null);}body{spec=s; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"debug="~spec.toString()~";";}
}
class DebugDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b, Statement e){cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"debug"~(cond?"("~cond.toString()~") ":"")~bdy.toString()~
			(els?(cast(BlockStm)bdy||cast(BlockDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class StaticIfDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b,Statement e)in{assert(c&&b);}body{cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"static if("~cond.toString()~") "~bdy.toString()~
			(els?(cast(BlockStm)bdy||cast(BlockDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class StaticAssertDecl: Declaration{
	Expression[] a;
	this(STC stc,Expression[] args){a = args; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"static assert("~join(map!(to!string)(a),",")~");";}
}

class MixinDecl: Declaration{
	Expression e;
	this(STC stc, Expression exp){e=exp; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"mixin("~e.toString()~");";}
}
class AliasDecl: Declaration{
	Declaration decl;
	this(STC stc, Declaration declaration){decl=declaration; super(stc, declaration.name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"alias "~decl.toString();}
}
class TypedefDecl: Declaration{
	Declaration decl;
	this(STC stc, Declaration declaration){decl=declaration; super(stc, declaration.name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"typedef "~decl.toString();}
}
class BlockDecl: Declaration{
	Declaration[] decls;
	this(STC s,Declaration[] declarations){stc=s; decls=declarations; super(stc,null);}
	override string toString(){return STCtoString(stc)~"{\n"~(stc?join(map!(to!string)(decls),"\n")~"\n}":indent(join(map!(to!string)(decls),"\n"))~"\n}");}
}
class AttributeDecl: Declaration{
	Declaration[] decls;
	this(STC stc,Declaration[] declarations){decls=declarations; super(stc,null);}
	override string toString(){return STCtoString(stc)~":\n"~join(map!(to!string)(decls),"\n");}
}

class TemplateParameter: Node{
	Identifier name;
	Expression type, spec, init;
	bool isAlias, isTuple;
	this(bool isa, bool ist, Expression tt, Identifier name, Expression specialization, Expression deflt){
		isAlias=isa, isTuple=ist; this.name = name;
		type=tt; spec=specialization; init=deflt;
	}
	override string toString(){
		return (isAlias?"alias ":"")~(type?type.toString()~" ":"")~(name?name.toString():"")~
			(isTuple?"...":"")~(spec?":"~spec.toString():"")~(init?"="~init.toString():"");
	}
}

class TemplateDecl: OverloadableDecl{
	bool ismixin;
	TemplateParameter[] params;
	Expression constraint;
	BlockDecl bdy;
	this(bool m,STC stc,Identifier name, TemplateParameter[] prm, Expression c, BlockDecl b){
		ismixin=m; params=prm; constraint=c; bdy=b; super(stc,name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"template "~name.toString()~"("~join(map!(to!string)(params),",")~")"~
			(constraint?" if("~constraint.toString()~")":"")~bdy.toString();
	}
}

class TemplateMixinDecl: Declaration{
	Expression inst;
	this(STC stc, Expression i, Identifier name)in{assert(i&&1);}body{inst=i; super(stc,name);}
	override string toString(){return "mixin "~inst.toString()~(name?" "~name.toString():"")~";";}
}

abstract class AggregateDecl: Declaration{
	BlockDecl bdy;
	this(STC stc, Identifier name, BlockDecl b){bdy=b; super(stc,name);}
}
class StructDecl: AggregateDecl{
	this(STC stc,Identifier name, BlockDecl b){super(stc,name,b);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"struct"~(name?" "~name.toString():"")~(bdy?bdy.toString():";");}
}
class UnionDecl: AggregateDecl{
	this(STC stc,Identifier name, BlockDecl b){super(stc,name,b);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"union"~(name?" "~name.toString():"")~(bdy?bdy.toString():";");}
}
struct ParentListEntry{
	STC protection;
	Expression symbol;
	string toString(){return (protection?STCtoString(protection)~" ":"")~symbol.toString();}
}
class ClassDecl: AggregateDecl{
	ParentListEntry[] parents;
	this(STC stc,Identifier name, ParentListEntry[] p, BlockDecl b){ parents=p; super(stc,name,b); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"class"~(name?" "~name.toString():"")~
			(parents?": "~join(map!(to!string)(parents),","):"")~(bdy?bdy.toString():"");}
}
class InterfaceDecl: AggregateDecl{
	ParentListEntry[] parents;
	this(STC stc,Identifier name, ParentListEntry[] p, BlockDecl b){ parents=p; super(stc,name,b); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"interface"~(name?" "~name.toString():"")~
			(parents?": "~join(map!(to!string)(parents),","):"")~(bdy?bdy.toString():";");}
}
class TemplateAggregateDecl: Declaration{
	TemplateParameter[] params;
	Expression constraint;
	AggregateDecl decl;
	this(STC stc,TemplateParameter[] p, Expression c, AggregateDecl ad){ params=p; constraint=c; decl=ad; super(stc,decl.name); }
	override string toString(){
		auto s=cast(StructDecl)decl, u=cast(UnionDecl)decl, c=cast(ClassDecl)decl, i=cast(InterfaceDecl)decl;
		string r=(stc?STCtoString(stc)~" ":"");
		r~=(s?"struct":u?"union":c?"class":"interface")~(decl.name?" "~name.toString():"")~"("~join(map!(to!string)(params),",")~")";
		if(c && c.parents) r~=": "~join(map!(to!string)(c.parents),",");
		if(i && i.parents) r~=": "~join(map!(to!string)(i.parents),",");
		auto bdy=s?s.bdy:u?u.bdy:c?c.bdy:i.bdy;
		return r~(constraint?" if("~constraint.toString()~")":"")~(bdy?bdy.toString():";");
	}
}

class TemplateFunctionDecl: OverloadableDecl{
	TemplateParameter[] params;
	Expression constraint;
	FunctionDecl fdecl;
	this(STC stc, TemplateParameter[] tp, Expression c, FunctionDecl fd){params=tp; constraint=c;fdecl=fd; super(stc, fdecl.name);}
	override string toString(){
		auto fd=cast(FunctionDef)fdecl;
		return (fdecl.type.stc?STCtoString(fdecl.type.stc)~" ":"")~(fdecl.type.ret?fdecl.type.ret.toString()~" ":"")~name.toString()~
			"("~join(map!(to!string)(params),",")~")"~fdecl.type.pListToString()~(constraint?" if("~constraint.toString()~")":"")
			~(fdecl.pre?"in"~fdecl.pre.toString():"")~(fdecl.post?"out"~(fdecl.postres?"("~fdecl.postres.toString()~")":"")~fdecl.post.toString():"")~
			(fd?(fd.pre||fd.post?"body":"")~fd.bdy.toString():!fdecl.pre&&!fdecl.post?";":"");
	}
}

class CArrayDecl: Declaration{
	Expression type;
	Expression init;
	Expression postfix; // reverse order
	this(STC stc, Expression type, Identifier name, Expression pfix, Expression initializer)in{assert(type&&name&&pfix);}body{
		this.stc=stc; this.type=type; postfix=pfix; init=initializer; super(stc,name);
	}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~type.toString()~" "~postfix.toString()~(init?"="~init.toString():"")~";";}
}

class VarDecl: Declaration{
	Expression type;
	Expression init;
	this(STC stc, Expression type, Identifier name, Expression initializer){this.stc=stc; this.type=type; init=initializer; super(stc,name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~(type?type.toString()~" ":"")~name.toString()~(init?"="~init.toString():"")~";";}

	override VarDecl isVarDecl(){return this;}
	override @property string kind(){return "variable";}

	mixin Visitors;
}
class Declarators: Declaration{
	VarDecl[] decls;
	this(VarDecl[] declarations)in{assert(declarations.length>1);foreach(x;declarations) assert(x.type is declarations[0].type);}body{
		decls=declarations;super(STC.init,null);
	}
	override string toString(){
		string r=(decls[0].stc?STCtoString(decls[0].stc)~" ":"")~(decls[0].type?decls[0].type.toString()~" ":"");
		//return r~join(map!((a){return a.name.toString();})(decls),","); // WTF???
		foreach(x;decls[0..$-1]) r~=x.name.toString()~(x.init?"="~x.init.toString():"")~",";
		return r~decls[$-1].name.toString()~(decls[$-1].init?"="~decls[$-1].init.toString():"")~";";
	}
	mixin Visitors;
}

class Parameter: VarDecl{ // for functions, foreach etc
	this(STC stc, Expression type, Identifier name, Expression initializer){super(stc,type,name,initializer);}
	override string toString(){return STCtoString(stc)~(stc&&type?" ":"")~(type?type.toString():"")~
			(name?(stc||type?" ":"")~name.toString():"")~(init?"="~init.toString():"");}
	//override @property string kind(){return "parameter";}
}
class PostblitParameter: Parameter{
	this(){super(STC.init,null,null,null);}
	override string toString(){return "this";}
}

class FunctionDecl: OverloadableDecl{
	FunctionType type;
	BlockStm pre,post;
	Identifier postres;
	this(FunctionType type,Identifier name,BlockStm pr,BlockStm po,Identifier pres)in{assert(type&&1);}body{
		this.type=type; pre=pr, post=po; postres=pres; super(type.stc, name);
	}
	override string toString(){
		return (type.stc?STCtoString(type.stc)~" ":"")~(type.ret?type.ret.toString()~" ":"")~name.toString()~type.pListToString()~
			(pre?"in"~pre.toString():"")~(post?"out"~(postres?"("~postres.toString()~")":"")~post.toString():"")~(!pre&&!post?";":"");
	}
	override @property string kind(){return "function";}
	override FunctionDecl isFunctionDecl(){return this;}
}

class FunctionDef: FunctionDecl{
	BlockStm bdy;
	this(FunctionType type,Identifier name, BlockStm precondition,BlockStm postcondition,Identifier pres,BlockStm fbody){
		super(type,name, precondition, postcondition, pres); bdy=fbody;}
	override string toString(){
		return (type.stc?STCtoString(type.stc)~" ":"")~(type.ret?type.ret.toString()~" ":"")~name.toString()~type.pListToString()~
			(pre?"in"~pre.toString():"")~(post?"out"~(postres?"("~postres.toString()~")":"")~post.toString():"")~(pre||post?"body":"")~bdy.toString();
	}

	mixin Visitors;
}

class UnitTestDecl: Declaration{
	BlockStm bdy;
	this(STC stc,BlockStm b)in{assert(b!is null);}body{ bdy=b; super(stc,null); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"unittest"~bdy.toString();}
}

class PragmaDecl: Declaration{
	Expression[] args;
	Statement bdy;
	this(STC stc,Expression[] a, Statement b)in{assert(b&&1);}body{args=a; bdy=b; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"pragma("~join(map!(to!string)(args),",")~")"~bdy.toString();}

	mixin Visitors;
}

enum LinkageType{
	D,
	C,
	CPP,
	Pascal,
	System,
	Windows,
}

class ExternDecl: Declaration{
	LinkageType linktype;
	Declaration decl;
	this(STC stc,LinkageType l,Declaration d)in{assert(d&&1);}body{
		linktype=l; decl=d;
		super(stc,d.name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"extern("~(linktype==LinkageType.CPP?"C++":to!string(linktype))~") "~decl.toString();
	}
}
class AlignDecl: Declaration{
	ulong alignment;
	Declaration decl;
	this(STC stc,ulong a,Declaration d)in{assert(d&&1);}body{
		alignment=a; decl=d;
		super(stc,d.name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"align("~to!string(alignment)~") "~decl.toString();
	}
}
