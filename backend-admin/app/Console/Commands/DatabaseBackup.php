<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use ZipArchive;
use Illuminate\Support\Facades\Mail;

class DatabaseBackup extends Command
{

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'backup:database';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Create and send a database backup';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $backup_type = appSettingData('get')->backup_type;

        if ( !isset($backup_type) ) {
            $this->error(__('message.not_found_entry',['name' => __('message.backup_type')]));
            return Command::FAILURE; 
        }

        if ( isset($backup_type) && !in_array($backup_type,['daily','weekly','monthly']) ) {
            $this->error('Database Backup Failed.');
            return Command::FAILURE;            
        }

        $filename = "backup-" . now()->format('Y-m-d_H-i-s') . ".sql";
        $directory = storage_path("app/backups");

        if (!file_exists($directory)) {
            mkdir($directory, 0755, true);
        }

        $path = $directory . '/' . $filename;
        
        $database = config('database.connections.mysql.database');
        $username = config('database.connections.mysql.username');
        $password = config('database.connections.mysql.password');
        $host = config('database.connections.mysql.host');

        $command = "mysqldump -h {$host} -u {$username} -p{$password} {$database} > {$path}";
        
        exec($command, $output, $returnVar);

        if ($returnVar !== 0) {
            return 'Database backup sent successfully';
        }

        $zip_file_path = $directory . "/backup-" . now()->format('Y-m-d_H-i-s') . ".zip";
        $zip = new ZipArchive();
        if ($zip->open($zip_file_path, ZipArchive::CREATE) === TRUE) {
            $zip->addFile($path, $filename);
            $zip->close();
            unlink($path);

            $backup_email = appSettingData('get')->backup_email;
            // \Log::info("Recipient email: $backup_email");
            $data = [
                'fileName' => basename($zip_file_path),
                'message' => 'Please find attached the latest database backup.',
            ];
        
            Mail::send('emails.databasebakupmail', $data, function ($message) use ($zip_file_path, $backup_email) {
                $message->to($backup_email)
                        ->subject('Database Backup')
                        ->attach($zip_file_path, [
                            'as' => basename($zip_file_path),
                            'mime' => 'application/zip',
                        ]);
            });

            unlink($zip_file_path);
            return true;
        } else {
            return false;
        }
        $this->info('Database backup sent successfully.');
        return Command::SUCCESS;
    }
}
