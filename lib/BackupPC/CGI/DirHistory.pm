#============================================================= -*-perl-*-
#
# BackupPC::CGI::DirHistory package
#
# DESCRIPTION
#
#   This module implements the DirHistory action for the CGI interface.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2003  Craig Barratt
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
#
# Version 2.1.0_CVS, released 3 Jul 2003.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

package BackupPC::CGI::DirHistory;

use strict;
use BackupPC::CGI::Lib qw(:all);
use BackupPC::View;
use BackupPC::Attrib qw(:all);

sub action
{
    my $Privileged = CheckPermission($In{host});
    my($i, $dirStr, $fileStr, $attr);
    my $checkBoxCnt = 0;

    if ( !$Privileged ) {
        ErrorExit(eval("qq{$Lang->{Only_privileged_users_can_browse_backup_files}}"));
    }
    my $host   = $In{host};
    my $share  = $In{share};
    my $dir    = $In{dir};
    my $dirURI = $dir;
    my $shareURI = $share;
    $dirURI    =~ s/([^\w.\/-])/uc sprintf("%%%02x", ord($1))/eg;
    $shareURI  =~ s/([^\w.\/-])/uc sprintf("%%%02x", ord($1))/eg;

    ErrorExit($Lang->{Empty_host_name}) if ( $host eq "" );

    my @Backups = $bpc->BackupInfoRead($host);
    my $view = BackupPC::View->new($bpc, $host, \@Backups);
    my $hist = $view->dirHistory($share, $dir);
    my($backupNumStr, $backupTimeStr, $fileStr);

    $dir = "/$dir" if ( $dir !~ /^\// );

    if ( "/$host/$share/$dir/" =~ m{/\.\./} ) {
        ErrorExit($Lang->{Nice_try__but_you_can_t_put});
    }

    for ( $i = 0 ; $i < @Backups ; $i++ ) {
	my $backupTime  = timeStamp2($Backups[$i]{startTime});
	my $num = $Backups[$i]{num};
	$backupNumStr  .= "<td align=center><a href=\"$MyURL?action=browse"
			. "&host=${EscURI($host)}&num=$num&share=$shareURI"
			. "&dir=$dirURI\">$num</a></td>";
	$backupTimeStr .= "<td align=center>$backupTime</td>";
    }

    foreach my $f ( sort {uc($a) cmp uc($b)} keys(%$hist) ) {
	my %inode2name;
	my $nameCnt = 0;
	(my $fDisp  = "${EscHTML($f)}") =~ s/ /&nbsp;/g;
	$fileStr   .= "<tr><td align=left>$fDisp</td>";
	my($colSpan, $url, $inode, $type);
	for ( $i = 0 ; $i < @Backups ; $i++ ) {
	    my($path);
	    if ( $colSpan > 0 ) {
		#
		# The file is the same if it also size==0 (inode == -1)
		# or if it is a directory and the previous one is (inode == -2)
		# or if the inodes agree and the types are the same.
		#
		if ( defined($hist->{$f}[$i])
		    && $hist->{$f}[$i]{type} == $type
		    && (($hist->{$f}[$i]{size} == 0 && $inode == -1)
		     || ($hist->{$f}[$i]{type} == BPC_FTYPE_DIR && $inode == -2)
		     || $hist->{$f}[$i]{inode} == $inode) ) {
		    $colSpan++;
		    next;
		}
		$fileStr .= "<td align=center colspan=$colSpan>$url</td>";
		$colSpan = 0;
	    }
	    if ( !defined($hist->{$f}[$i]) ) {
		$fileStr .= "<td></td>";
		next;
	    }
            if ( $dir eq "" ) {
                $path = "/$f";
            } else {
                ($path = "$dir/$f") =~ s{//+}{/}g;
            }
	    $path =~ s{^/+}{/};
	    $path =~ s/([^\w.\/-])/uc sprintf("%%%02X", ord($1))/eg;
	    my $num = $hist->{$f}[$i]{backupNum};
	    if ( $hist->{$f}[$i]{type} == BPC_FTYPE_DIR ) {
		$inode = -2;
		$type  = $hist->{$f}[$i]{type};
		$url   = <<EOF;
<a href="$MyURL?action=dirHistory&host=${EscURI($host)}&num=$num&share=$shareURI&dir=$path">dir</a>
EOF
	    } else {
		$inode = $hist->{$f}[$i]{inode};
		$type  = $hist->{$f}[$i]{type};
		$inode = -1 if ( $hist->{$f}[$i]{size} == 0 );
		if ( !defined($inode2name{$inode}) ) {
		    $inode2name{$inode} = "v$nameCnt";
		    $nameCnt++;
		}
		$url = <<EOF;
<a href="$MyURL?action=RestoreFile&host=${EscURI($host)}&num=$num&share=$shareURI&dir=$path">$inode2name{$inode}</a>
EOF
	    }
	    $colSpan = 1;
	}
	if ( $colSpan > 0 ) {
	    $fileStr .= "<td align=center colspan=$colSpan>$url</td>";
	    $colSpan = 0;
	}
	$fileStr .= "</tr>\n";
    }

    my $dirDisplay = "$share/$dir";
    $dirDisplay =~ s{//+}{/}g;
    $dirDisplay =~ s{/+$}{}g;
    $dirDisplay = "/" if ( $dirDisplay eq "" );

    Header(eval("qq{$Lang->{DirHistory_backup_for__host}}"));

    print (eval("qq{$Lang->{DirHistory_for__host}}"));

    Trailer();
}

1;
