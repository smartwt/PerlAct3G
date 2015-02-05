#!/usr/bin/perl -w
use strict;
use warnings;
use NET::SMTP;
use utf8;
use Encode;
use MIME::Base64;
<<<<<<< HEAD
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

=======


my $HOSTFILE="hostlist";
my $ACCOUNT="swing";
my $PASSWORD="swinguser";
>>>>>>> parent of 28320b6... 暫定
my $SYSSWITCH_COMM ="sudo /home/swing/sysswitchctl";

my $CAPACITYCTL_COMM ="sudo /home/swing/capacityctl ";


# 読み込みたいファイル名
my $file = $HOSTFILE; 

open(my $fh, "<", $file)
  or die "Cannot open $file: $!";
	# readline関数で、一行読み込む。
	while(my $line = readline $fh){ 
		# chomp関数で、改行を取り除く
		chomp $line;
		
		# $line に対して何らかの処理。
		# 標準出力へ書き出し。
		print $line, "\n";
		
		my $task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $SYSSWITCH_COMM";

		my $shstlist = qx ($task) or die "Unable to open SYSSWITCHCTL \n";
		#chomp @shstlist;
		print "$shstlist";
		
		#現用系の時のみ
		if ($shstlist =~/ACT/){
			
<<<<<<< HEAD
	
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
=======
			#$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $CAPACITYCTL_COMM > $line"."_CAPACITYCTL.txt";
			$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $CAPACITYCTL_COMM ";
>>>>>>> parent of 28320b6... 暫定

			my @shstlista = qx ($task) or die "Unable to open CAPACITYCTL \n";
			&mailSend($line,@shstlista);
			#print "@shstlista";

		}

		# ファイルがEOF( END OF FILE ) に到達するまで1行読みこみを繰り返す。
	}

close $fh;

sub mailSend{
	my ($host,@text) = @_;
	# メール送信に使うSMTPサーバーと、ポート番号、送信者のドメインを設定する。
	my $smtp_server = 'smtp';
	my $smtp_port = '25';
	my $smtp_helo = 'actwatch.com';

	# 送信者の名前とメールアドレスを設定する。
	my $mail_from_name = 'ACTWATCH3G';
	my $mail_from = 'mp1@ab.actwatch.net';

	# 宛先の宛名とメールアドレスを設定する。
	my $mail_to_name = 'ACTWATCHC3G';
	my $mail_to = 'y-satou@z6.nesic.com';

	# メールの件名を設定する。
	my $subject = 'Capacityctl_[ACT]'.$host;

	# メールヘッダを作成する。
	# from、to、件名共にMIME-Header(UTF-8)へエンコードします。
	my $mail_header;

	# 送信者名、送信者のメールアドレスを、
	# From: 送信者名 <送信者メールアドレス> 形式へ変換する。
	$mail_header = make_name_addr('From:',$mail_from_name,$mail_from);

	# 宛名、宛先のメールアドレスを、
<<<<<<< HEAD
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
=======
	# To: 宛名 <宛先メールアドレス> 形式へ変換する。
	$mail_header .= make_name_addr('To:',$mail_to_name,$mail_to);

	# 件名をMIMEエンコードする。
	$mail_header .= 'Subject: '.encode('MIME-Header',$subject)."\n";

	# UTF-8とbase64エンコードを使う事を明記します。
	$mail_header .= "MIME-Version: 1.0\n";
	$mail_header .= "Content-type: text/plain; charset=UTF-8\n";
	$mail_header .= "Content-Transfer-Encoding: base64\n";

	# メールヘッダの終わり。(これ以降は本文となります。)
	$mail_header .= "\n";

	# SMTPでメールを送る。
	my $SMTP=Net::SMTP->new($smtp_server,Port=>$smtp_port,Hello=>$smtp_helo);
	if (!$SMTP) { die "Error : Can not connect to mail server.\n"; }
	$SMTP->mail($mail_from);
	$SMTP->to($mail_to);
	$SMTP->data();
	$SMTP->datasend($mail_header);
	$SMTP->datasend(encode_base64(encode('utf8',join('',@text))));
	$SMTP->dataend();
	$SMTP->quit;

	exit;
>>>>>>> parent of 28320b6... 暫定
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


	
	

<<<<<<< HEAD
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
=======





>>>>>>> parent of 28320b6... 暫定
