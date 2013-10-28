#!/usr/bin/perl -w
use strict;
use warnings;
use NET::SMTP;
use utf8;
use Encode;
use MIME::Base64;


my $HOSTFILE="hostlist";
my $ACCOUNT="swing";
my $PASSWORD="swinguser";
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
			
			#$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $CAPACITYCTL_COMM > $line"."_CAPACITYCTL.txt";
			$task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $line $CAPACITYCTL_COMM ";

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


	
	






