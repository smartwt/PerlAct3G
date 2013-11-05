#!/usr/bin/perl -w
use strict;
use warnings;
use NET::SMTP;
use utf8;
use Encode;
use MIME::Base64;
use File::Basename;

require "./lib/mimew.pl";
require "./lib/logger.pl";

# 宛先の宛名とメールアドレスを設定する。
my $mail_to = 
#複数送信の時は配列に格納
my @mailAddressArray = split(/,/,$mail_to);

# メール送信に使うSMTPサーバーと、ポート番号、送信者のドメインを設定する。
my $smtp_server = '';
my $smtp_port = '';
my $smtp_helo = '';

# 送信者の名前とメールアドレスと表題
my $mail_from_name = 'ACTWATCH3G 日次チェック';
#my $mail_from = '';
my $mail_from = '';


# メールタイトル
my $subject = '【レポート】Check Result';


my $HOSTFILE="";
my $ACCOUNT="";
my $PASSWORD="";

my $SYSSWITCH_COMM ="sudo /home/swing/sysswitchctl";
my $CAPACITYCTL_COMM ="sudo /home/swing/capacityctl";
#バックアップファイル数の取得
my $BACKUPCHKCOMM = "ls -1  /usr/local/SWing/backup/system";
my $AUDIT_LOG ="cat /usr/local/SWing/audit/swing_auto_audit.log > ";

my @text = ();
my @tmptext = ();
my @flist = ();

open(my $fh, "<", $HOSTFILE)
  or die logger("Cannot open $HOSTFILE: $! \n");
  
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
	my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);  
	
	# readline関数で、一行読み込む。
	while(my $line = readline $fh){ 
		# chomp関数で、改行を取り除く
		chomp $line;
		
		#コメント　空文字は次へ
		if ($line =~ /^#/ or $line eq ''){
			next;
		}
		$line = trim($line);
		# 標準出力へ書き出し。
		print $line;
		push (@text,"■ $line \r\n");

		my $task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $SYSSWITCH_COMM";
		my $shstlist = qx ($task);
		if($?){
			logger ($line." Command Error \"$SYSSWITCH_COMM\" $!");
			push (@text," Command Error \"$SYSSWITCH_COMM\" $! \r\n");
		}

		#chomp @shstlist;
		print $shstlist;
		#現用系の時のみ
		if ($shstlist =~/ACT/){
	
			#バックアップ数の取得
			@tmptext = &backupchk($line);
			unshift (@tmptext,"【ACT】 バックアップ確認 "."\r\n");
			push(@tmptext,"\n");
			push (@text,@tmptext);
			
	
			#現用統合サーバのみCAPACITYCTL auditlog
			if( $line eq "pesis11" or $line eq "pesis12" or $line eq "192.168.22.1" or $line eq "192.168.22.2"){
				#capacity取得
				$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $CAPACITYCTL_COMM > ". $line."_Capacityctl_".$yyyymmdd.".txt";
				my @shstlista = qx ($task);
				if($?){
					logger ($line." Command Error \"$CAPACITYCTL_COMM\" $!");
					push (@text,"  Command Error \"$CAPACITYCTL_COMM\" \r\n");
				}else{
					#添付ファイル名を格納
					push(@flist,$line."_Capacityctl_".$yyyymmdd.".txt");
				}
				
				####################### auditlog取得 #######################
				my $outputFname = $line."_swing_auto_audit_".$yyyymmdd.".txt";
				$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $AUDIT_LOG ". "Tmp_".$outputFname;

				@shstlista = qx ($task);
				if($?){
					logger ($line." AuditLog Get Error \"$AUDIT_LOG\" $!");
					push (@text,"  AuditLog Get Error \"$AUDIT_LOG\" \r\n");
				}else{
				
					#本日分のAuditログを取得するオブジェクトを定義
					my $audob = Class_AuditLog->new();
					$audob->auditlognamein("Tmp_".$outputFname);
					$audob->auditlognameout($outputFname);
					
					my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);	
					my $nowdate = sprintf("%04d-%02d-%02d",$year+1900,$mon+1,$mday);
					$audob->pattern($nowdate);
					#今日分のAuditLogを取得
					my $ret = $audob->getAuditTodayLog;

					#引数に値が入っていたらエラー
					if($ret eq ""){
						#添付ファイル名を格納
						push(@flist,$outputFname);

					}
					#1の場合
					elsif ($ret eq "1"){
						logger ($line." $outputFname ローテーションされている恐れがあります。");
						push (@text,"    $outputFname  ローテーションされている恐れがあります。"."\r\n");
						
						#添付ファイル名を格納
						push(@flist,$outputFname);
					}else{
						logger ($line.$ret);
						push (@text,$ret."\r\n\r\n");

					}
				}
			}
		}
		elsif ($shstlist =~/SBY/){

			#バックアップ数の取得
			@tmptext = &backupchk($line);
			unshift(@tmptext,"【SBY】 バックアップ確認 "."\r\n");
			push(@tmptext,"\r\n");
			push (@text,@tmptext);

		}
		# ファイルがEOF( END OF FILE ) に到達するまで1行読みこみを繰り返す。
	}
	#メールの送信
	&mailSend(\@flist,\@text);
	
	#一時ファイルの削除
	for( my $c=0; $c <= $#flist; $c++){
		unlink $flist[$c];
	}
close $fh;


sub mailSend{

	# バウンダリ
	my $bound = 'wq5se3d1ew';

	my ($filelist,$textad) = @_;
	my @flist = @{$filelist};
	my @text = @{$textad};
	
	
	# 添付ファイルをBase64エンコードする
	my $base64_data;
	my @base64_data_array;
		
	for( my $i=0; $i <= $#flist; $i++){
		
		if ( $flist[$i] ){
			if(!open FF,$flist[$i]){
				logger ("Cannot Open $flist[$i] \n");
				unshift (@text,"Cannot Open $flist[$i]"."\r\n\r\n");
			}else{
				
				$base64_data = join('',<FF>);
				close(FF);
				$base64_data = &bodyencode($base64_data,"b64");
				$base64_data .= &benflush("b64");
				push(@base64_data_array,$base64_data);
			}
		}
	}
	# 送信者名、送信者のメールアドレスを、
	# From: 送信者名 <送信者メールアドレス> 形式へ変換する。
	my $from = make_name_addr('From:',$mail_from_name,$mail_from);

	# 宛名、宛先のメールアドレスを、
	#my $to = make_name_addr('To:',$mail_to_name,$mail_to);
	my $to = "To: ".trim($mail_to)."\n";

	# ヘッダ
	my $smtp = Net::SMTP->new($smtp_server,Port=>$smtp_port,Hello=>$smtp_helo) or die logger("SMTP SERVER CONNECT ERROR $!" );
	#送信元の指定
	$smtp->mail($mail_from) or die logger("MAIL SENDER ERROR $!" );
	
	#宛先の指定
	$smtp->to(@mailAddressArray);
	my $date = &date;
	$smtp->data();
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-Type: Multipart/Mixed; boundary=\"$bound\"\n");
	$smtp->datasend("Content-Transfer-Encoding:Base64\n");
	$smtp->datasend("Date:$date\n");
	$smtp->datasend("$from");
	$smtp->datasend("$to");
	# $smtp->datasend("Cc:$cc\n");
	$smtp->datasend("Subject: ".encode('MIME-Header',.$subject)."\n");
	$smtp->datasend("--$bound\n");
	$smtp->datasend("Content-Type: text/plain; charset=\"UTF-8\"\n\n");
	#本文
	$smtp->datasend(join('',@text));

	# 添付
	for( my $i=0; $i <= $#flist; $i++){
		my $filenmame = $flist[$i];
		if ( $base64_data_array[$i] ){ 
			$smtp->datasend("--$bound\n"); 
			$smtp->datasend("Content-Transfer-Encoding: BASE64\n");
			$smtp->datasend("Content-Type:application/octet-stream; name=$filenmame\"\n\n");
			$smtp->datasend("$base64_data_array[$i]\n"); 
			#$smtp->datasend("--$bound\n");
		}
	}
	# データの終わり、メール送信
	$smtp->dataend();
	#SMTP接続の終了
	$smtp->quit;
}

# 名前とメールアドレスから、name_addr形式のフォーマットを作るサブルーチン。
sub make_name_addr {
	# 引数を受け取る。
	my ($mail_direction,$mail_name,$mail_address) = @_;
	# 末尾にスペースを追加して"From: "または "To: "を作る。
	my $name_addr = $mail_direction.' ';

	# 名前(送信者名または宛名)が設定されているか調べる。
	if ($mail_name ne "") {
		# 名前が設定されていたら、
		# 名前をMIMEエンコードして、末尾にスペースを追加する。
		$name_addr .= encode('MIME-Header',$mail_name).' ';
	}
	# メールアドレスを追加する。
	return ($name_addr .= '<'.$mail_address.">\n");
}
sub date { 
	$ENV{'TZ'} = "JST-9";
	my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
	my @week = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'); 
	my $d = sprintf("%s, %d %s %04d %02d:%02d:%02d +0900 (JST)", $week[$wday],$mday,$month[$mon],$year+1900,$hour,$min,$sec);
	return $d;
}
sub trim {
	my $val = shift;
	$val =~ s/^ *(.*?) *$/$1/;
	return $val;
}


#バックアップファイル数の取得
sub backupchk{
	my $host = shift;
	
	#/usr/local/SWing/backup/system
	my $task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $host $BACKUPCHKCOMM" ;

	my @shstlist = qx ($task);
	if($?){
		logger ($host." BackUp Directory Get Error \"$BACKUPCHKCOMM\" $!");
		push (@shstlist,"   BackUp Directory Get Error \"$BACKUPCHKCOMM\"");
	}
	
	#スペースを入れて字下げする
	my @arr = map{ "   ". $_ } @shstlist;
	
	return @arr;
}

#AuditLogの取得
package Class_AuditLog;
use utf8;
use Encode;
#コンストラクタ
sub new {
	
	my $class = shift;
	my $audit = {
		#コマンドにより吐き出されるファイル
		auditlognamein => undef,
		#出力ファイル
		auditlognameout => undef,
		#検索パターン
		pattern => undef,
	};
	bless ($audit,$class);
	return $audit;
}
#インプットファイル
sub auditlognamein {
	my $audit = shift;
	if(@_) { $audit->{auditlognamein} = shift}
	return $audit->{auditlognamein};
}
sub auditlognameout {
	my $audit = shift;
	if(@_) { $audit->{auditlognameout} = shift}
	return $audit->{auditlognameout};
}
sub pattern {
	my $audit = shift;
	if(@_) { $audit->{pattern} = shift}
	return $audit->{pattern};
}
#本日分のAuditログを取得する
sub getAuditTodayLog{
	my $audit = shift;
	my $ret = "";
	#一時ファイルを開く
	if(!open(IN, "<:utf8", $audit->{auditlognamein})){
		return "   AuditLog File Open Error \"$audit->{auditlognamein}\" $!";
	}
	
	#見つかったらフラグ
	my $flg=0;
	#一行ずつ見る
	while(my $dataline = readline IN){ 
		if ($flg == 1 ){
			print OUT encode('utf-8',$dataline); 
		}
		else{
			#検索し見つけたらフラグをあげる
			if ($dataline =~/$audit->{pattern}/){
				$flg=1;
				
				#1行目を書き込み
				if(!open(OUT,">>$audit->{auditlognameout}")){
					close(IN);
					return "   AuditLog File Write Error \"$audit->{auditlognameout}\" $!";
				}
				#ローテーションされてない場合先頭に「定期Audit開始」の文言がでる
				if($dataline !~/定期Audit開始/){
					
					#ローテーションされている恐れがある場合
					$ret = "1";
				}
				print OUT encode('utf-8',$dataline); 

			}
		}
	}
	
	close(IN);
	close(OUT);
	if ($flg == 0 ){
		return "   何らかの原因により\"$audit->{auditlognameout}\"ログが取得できませんでした。";
	}
	
	#出力終わったら一時ファイルを消す
	unlink $audit->{auditlognamein};
	return $ret;
}
