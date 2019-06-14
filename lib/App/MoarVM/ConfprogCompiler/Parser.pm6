unit module App::MoarVM::ConfprogCompiler::Parser;

use App::MoarVM::ConfprogCompiler::Parser::Grammar;
use App::MoarVM::ConfprogCompiler::Parser::Actions;

our sub parse-confprog($sourcecode) is export {
    ConfProg.parse($sourcecode, actions => ConfProgActions.new);
}
