#bash

# For use with Mac systems that make use of MacPorts.
if [[ -d '/opt/local/bin' ]]; then
   export PATH=/opt/local/bin:/opt/local/sbin:$PATH
fi


# Force utilities to write bash-style no matter what the inherited
# setting of SHELL is by overwriting it to the path to the 
# currently running version of bash (identified by the BASH 
# special variable).
export SHELL="$BASH"


# Add my bin to the front of the PATH, if it's there.
# This should be the final modification to PATH in this configuration file.
if [[ -d "$HOME/bin" ]]; then
   export PATH="$HOME/bin:$PATH"
fi


# Personal configuration preferences
export EDITOR=$(type -P vim 2>/dev/null)
export PAGER=$(type -P less 2>/dev/null)
IGNOREEOF=10 # Require very persistent ctrl+d pressing before accepting it.
PS1="\[\033[0;37m\][\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;33m\]\h\[\033[0;37m\]]:\[\033[0;35m\]\W\[\033[0;37m\]\$\[\033[0m\] "
unset HISTFILE

set -o vi
shopt -s extglob


# Use colour ls.
# If this system is a Mac, target BSD ls.
# Otherwise, assume that GNU ls is the default.
if [[ "$(uname -s)" = 'Darwin' ]]; then
   export CLICOLOR=1
   export LSCOLORS=GxFxDxDxhxDgDxabagacad
   alias ls='ls -F -G'
else
   # Check the same directory as this file for configuration in case of testing.
   # Fall back to the home directory, although that's likely to be this directory.
   if [[ -r "$(dirname "${BASH_SOURCE[0]}")"/.dircolorsrc ]]; then
      eval $(dircolors -b "$(dirname "${BASH_SOURCE[0]}")"/.dircolorsrc)
   elif [[ -r "$HOME/.dircolorsrc" ]]; then 
      eval $(dircolors -b "$HOME/.dircolorsrc")
   fi
   alias ls='ls -F --color=auto'
fi


# A few aliases to override commands with some helpful default options.
# The localhost override for ssh and scp was particularly useful on UW
# systems, as multiple different machines shared the same filesystem and
# therefore the same cached key for localhost.
alias ssh='ssh -Y -o "NoHostAuthenticationForLocalhost=yes"'
alias scp='scp -o "NoHostAuthenticationForLocalhost=yes"'
alias pine='pine -i'

# Make info usable for vi-oriented people
alias info="info --vi-keys"


# In a source tree, find all non-svnadmin files, also excluding backup files.
# Then, run grep; any flags and the pattern to search for must be supplied, but
# the arguments will follow automatically (so avoid the -r flag or providing
# filenames to match)
alias srcgrep='find . -name .svn -prune -o -name "*~" -prune -o -name ".nfs*" -prune -o -type f -print0 | xargs -0 grep --binary-files=without-match'

# Check the status, ignoring files that are not in the repository.
# Sometimes you want to see them, but often so many files are listed
# that any missing files would go unnoticed anyway.
alias svnst="svn st | grep -v '^?'"



# Helper functions

# On the Solaris 8 servers at UW, there was a special custom command that
# would take any number of paths as arguments and output canonical paths
# corresponding to each argument.
#
# The equivalent on Linux systems for a single file appears to be using
# the readlink command with the -f option.  Unfortunately, readlink on
# the UW Solaris 8 servers referred to an incompatible command in the
# tetex package, and readlink on BSD (Mac OS) is a synonym for stat.
# 
# To handle these incompatibilities, I decided to try to create an absolute
# bash function that would mimic the absolute command whether it was
# using absolute or readlink.  This function actually either unsets itself
# or overwrites itself with a simpler absolute function after the first
# time it is run; it's not clear to me whether or not this is a good idea
# in terms of typical performance, but it does simplify the output of the
# type builtin and I wanted to verify that it was possible to do this in bash.
absolute () 
{ 
   if type -P $FUNCNAME >/dev/null 2>&1; then
      # Unset the function; just let the command get hashed
      # and do the work directly.
      unset $FUNCNAME
      $FUNCNAME "$@"
      return
   fi

   # Search through a list of potential names for GNU readlink,
   # in priority order.
   # Note that "readlink" is dangerous; on the University of Waterloo
   # Solaris 8 servers, it's some command in the tetex-1.0 package
   # by default; on installations of Mac OS X, it's the BSD version
   # with incompatible options.
   # On Solaris 8, absolute will be found above; on Mac, this will only
   # work if a prefixed coreutils package is installed (for example,
   # via fink or macports) and in the PATH.
   local -a rlpotentials=( gnureadlink greadlink readlink )
   local pot
   for pot in "${rlpotentials[@]}"; do
      if type -P "$pot" >/dev/null 2>&1; then
         eval "$FUNCNAME () {
            for file in \"\$@\"; do
               \"$pot\" -f \"\$file\"
            done
         }";
         $FUNCNAME "$@"
         return
      fi;
   done

   # If this gets this far... give up.
   # Overwrite the absolute function with one that will ignore
   # arguments and just dump an error message.
   absolute () 
   { 
      echo "Error: no $FUNCNAME command or substitute can be found" 1>&2;
      return 15
   };
   $FUNCNAME 
}


# Eliminate temporary/backup files that I no longer want to see.
# Perform this task only in the current directory by default, but
# allow it to be done recursively.
cleanup () {
   local -a rec=( '-maxdepth' 1 )

   # If the option -r is specified, perform recursive cleanup
   if [[ "$#" -eq 1 ]] && [[ "$1" == '-r' ]]; then
      rec=( )
   elif [[ "$#" -ne 0 ]]; then
      echo "Usage: $FUNCNAME [-r]" >&2
      return 15
   fi

   # Use a temporary file so the names of the files being deleted
   # can be output before deletion.
   # Use file I/O to do this instead of internal string storage to 
   # simplify handling of the null character.
   local tmpfile="/tmp/cleanup.$$"
   touch "$tmpfile"
   chmod 600 "$tmpfile"

   # Find files matching particular patterns.
   # Explicitly name the type as file to avoid matching directories.
   find . "${rec[@]}" -type f \( \
        -name '*~' -o -name "*.bak" \
        \) -print0 > "$tmpfile"

   # On some systems, xargs does nothing when passed empty input.
   # On others, it still happily tries to execute the command.
   # So, make sure the file is non-empty before attempting anything.
   if [ -s "$tmpfile" ]; then
      xargs -0 echo rm < "$tmpfile"
      xargs -0 rm < "$tmpfile"
   fi

   rm "$tmpfile"
}
