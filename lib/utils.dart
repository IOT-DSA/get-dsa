library get_dsa.utils;

import "dart:async";
import "dart:typed_data";

import "package:archive/archive.dart" hide Deflate;

part "src/deflate.dart";

Future<Archive> readArchive(List<int> bytes, {bool decompress: false}) async {
  if (bytes[0] == 80 && bytes[1] == 75 && bytes[2] == 3 && bytes[3] == 4) {
    Archive archive = await (new CustomZipDecoder().decodeBytes(bytes));
    for (var file in archive.files) {
      if (decompress) {
        if (file.isCompressed) {
          file.decompress();
        }

        if (!file.name.endsWith(".js")) {
          file.compress = false;
        }
      }
    }
    return archive;
  } else {
    throw new Exception("Unknown Archive Format");
  }
}

Future<List<int>> compressZip(Archive archive) async {
  for (var file in archive.files) {
    if (file.name.endsWith(".zip")
      || file.name.endsWith(".png")
      || file.name.endsWith(".jpg")
      || file.name.endsWith("BUILD_NUMBER")
      || file.name.endsWith(".jpeg")
      || file.name.endsWith(".gif")) {
      file.compress = false;
    }
  }

  return await (new CustomZipEncoder().encode(archive, level: Deflate.NO_COMPRESSION));
}

class CustomZipDecoder {
  CustomZipDirectory directory;

  Future<Archive> decodeBytes(List<int> data, {bool verify: false}) async {
    return await decodeBuffer(new InputStream(data), verify: verify);
  }

  Future<Archive> decodeBuffer(InputStream input, {bool verify: false}) async {
    directory = new CustomZipDirectory.readInputStream(input);
    await directory.read();
    Archive archive = new Archive();

    for (ZipFileHeader zfh in directory.fileHeaders) {
      await new Future.value();
      ZipFile zf = zfh.file;

      if (verify) {
        int computedCrc = getCrc32(zf.content);
        if (computedCrc != zf.crc32) {
          throw new ArchiveException('Invalid CRC for file in archive.');
        }
      }

      var content = zf.content;
      ArchiveFile file = new ArchiveFile(zf.filename, zf.uncompressedSize, content, zf.compressionMethod);
      file.crc32 = zf.crc32;

      var isDirectory = (zfh.externalFileAttributes & 0x0010) == 1 ? true : false;
      file.isFile = !isDirectory;

      file.mode = (zfh.externalFileAttributes >> 16) & 0xFFFF;

      archive.addFile(file);
    }

    return archive;
  }
}

class CustomZipEncoder {
  Future<List<int>> encode(Archive archive, {int level: Deflate.BEST_SPEED}) async {
    DateTime dateTime = new DateTime.now();
    int t1 = ((dateTime.minute & 0x7) << 5) | (dateTime.second ~/ 2);
    int t2 = (dateTime.hour << 3) | (dateTime.minute >> 3);
    int time = ((t2 & 0xff) << 8) | (t1 & 0xff);

    int d1 = ((dateTime.month & 0x7) << 5) | dateTime.day;
    int d2 = (((dateTime.year - 1980) & 0x7f) << 1)
    | (dateTime.month >> 3);
    int date = ((d2 & 0xff) << 8) | (d1 & 0xff);

    int localFileSize = 0;
    int centralDirectorySize = 0;
    int endOfCentralDirectorySize = 0;

    Map<ArchiveFile, Map> fileData = {};

    // Prepare the files, so we can know ahead of time how much space we need
    // for the output buffer.
    for (ArchiveFile file in archive.files) {
      await new Future.value();
      fileData[file] = {};
      fileData[file]['time'] = time;
      fileData[file]['date'] = date;

      InputStream compressedData;
      int crc32;

      // If the user want's to store the file without compressing it,
      // make sure it's decompressed.
      if (!file.compress) {
        if (file.isCompressed) {
          file.decompress();
        }

        compressedData = new InputStream(file.content);

        if (file.crc32 != null) {
          crc32 = file.crc32;
        } else {
          crc32 = getCrc32(file.content);
        }
      } else if (!file.compress ||
      file.compressionType == ArchiveFile.DEFLATE) {
        // If the file is already compressed, no sense in uncompressing it and
        // compressing it again, just pass along the already compressed data.
        compressedData = file.rawContent;

        if (file.crc32 != null) {
          crc32 = file.crc32;
        } else {
          crc32 = getCrc32(file.content);
        }
      } else {
        // Otherwise we need to compress it now.
        crc32 = getCrc32(file.content);

        Deflate deflate = new Deflate(file.content, level: level);

        await deflate.deflate();

        List<int> bytes = deflate.getBytes();
        compressedData = new InputStream(bytes);
      }

      localFileSize += 30 + file.name.length + compressedData.length;

      centralDirectorySize += 46 + file.name.length +
      (file.comment != null ? file.comment.length : 0);

      fileData[file]['crc'] = crc32;
      fileData[file]['size'] = compressedData.length;
      fileData[file]['data'] = compressedData;
    }

    endOfCentralDirectorySize = 46 + (archive.comment != null ? archive.comment.length : 0);

    int outputSize = localFileSize + centralDirectorySize + endOfCentralDirectorySize;

    OutputStream output = new OutputStream(size: outputSize);

    // Write Local File Headers
    for (ArchiveFile file in archive.files) {
      fileData[file]['pos'] = output.length;
      await _writeFile(file, fileData, output);
    }

    // Write Central Directory and End Of Central Directory
    await _writeCentralDirectory(archive, fileData, output);

    return output.getBytes();
  }

  _writeFile(ArchiveFile file, Map fileData, OutputStream output) async {
    output.writeUint32(ZipFile.SIGNATURE);

    int version = VERSION;
    int flags = 0;
    int compressionMethod = file.compress ? ZipFile.DEFLATE : ZipFile.STORE;
    int lastModFileTime = fileData[file]['time'];
    int lastModFileDate = fileData[file]['date'];
    int crc32 = fileData[file]['crc'];
    int compressedSize = fileData[file]['size'];
    int uncompressedSize = file.size;
    String filename = file.name;
    List<int> extra = [];

    InputStream compressedData = fileData[file]['data'];

    output.writeUint16(version);
    output.writeUint16(flags);
    output.writeUint16(compressionMethod);
    output.writeUint16(lastModFileTime);
    output.writeUint16(lastModFileDate);
    output.writeUint32(crc32);
    output.writeUint32(compressedSize);
    output.writeUint32(uncompressedSize);
    output.writeUint16(filename.length);
    output.writeUint16(extra.length);
    output.writeBytes(filename.codeUnits);
    output.writeBytes(extra);

    output.writeInputStream(compressedData);
  }

  _writeCentralDirectory(Archive archive, Map fileData,
                              OutputStream output) async {
    int centralDirPosition = output.length;

    int version = VERSION;
    int os = OS_UNIX;

    for (ArchiveFile file in archive.files) {
      await new Future.value();
      int versionMadeBy = (os << 8) | version;
      int versionNeededToExtract = version;
      int generalPurposeBitFlag = 0;
      int compressionMethod = file.compress ? ZipFile.DEFLATE : ZipFile.STORE;
      int lastModifiedFileTime = fileData[file]['time'];
      int lastModifiedFileDate = fileData[file]['date'];
      int crc32 = fileData[file]['crc'];
      int compressedSize = fileData[file]['size'];
      int uncompressedSize = file.size;
      int diskNumberStart = 0;
      int internalFileAttributes = 0;
      var fmode = file.mode != null ? file.mode : 0;

      var x = fmode;

      if (x == null || x == 0) {
        x = (file.name.endsWith("/") || !file.isFile) ? 0x41fd : 0x81b4;
      }

      var efa = 0;

      efa |= (!file.isFile ? 0x00010 : 0);

      efa |= (x & 0xFFFF) << 16;

      int localHeaderOffset = fileData[file]['pos'];
      String filename = file.name;
      List<int> extraField = [];
      String fileComment = (file.comment == null ? '' : file.comment);

      output.writeUint32(ZipFileHeader.SIGNATURE);
      output.writeUint16(versionMadeBy);
      output.writeUint16(versionNeededToExtract);
      output.writeUint16(generalPurposeBitFlag);
      output.writeUint16(compressionMethod);
      output.writeUint16(lastModifiedFileTime);
      output.writeUint16(lastModifiedFileDate);
      output.writeUint32(crc32);
      output.writeUint32(compressedSize);
      output.writeUint32(uncompressedSize);
      output.writeUint16(filename.length);
      output.writeUint16(extraField.length);
      output.writeUint16(fileComment.length);
      output.writeUint16(diskNumberStart);
      output.writeUint16(internalFileAttributes);
      output.writeUint32(efa);
      output.writeUint32(localHeaderOffset);
      output.writeBytes(filename.codeUnits);
      output.writeBytes(extraField);
      output.writeBytes(fileComment.codeUnits);
    }

    int numberOfThisDisk = 0;
    int diskWithTheStartOfTheCentralDirectory = 0;
    int totalCentralDirectoryEntriesOnThisDisk = archive.numberOfFiles();
    int totalCentralDirectoryEntries = archive.numberOfFiles();
    int centralDirectorySize = output.length - centralDirPosition;
    int centralDirectoryOffset = centralDirPosition;
    String comment = (archive.comment == null ? '' : archive.comment);

    output.writeUint32(ZipDirectory.SIGNATURE);
    output.writeUint16(numberOfThisDisk);
    output.writeUint16(diskWithTheStartOfTheCentralDirectory);
    output.writeUint16(totalCentralDirectoryEntriesOnThisDisk);
    output.writeUint16(totalCentralDirectoryEntries);
    output.writeUint32(centralDirectorySize);
    output.writeUint32(centralDirectoryOffset);
    output.writeUint16(comment.length);
    output.writeBytes(comment.codeUnits);
  }

  static const int VERSION = 20;

  // enum OS
  static const int OS_MSDOS = 0;
  static const int OS_UNIX = 3;
  static const int OS_MACINTOSH = 7;
}

class CustomZipDirectory {
  // End of Central Directory Record
  static const int SIGNATURE = 0x06054b50;
  static const int ZIP64_EOCD_LOCATOR_SIGNATURE = 0x07064b50;
  static const int ZIP64_EOCD_LOCATOR_SIZE = 20;
  static const int ZIP64_EOCD_SIGNATURE = 0x06064b50;
  static const int ZIP64_EOCD_SIZE = 56;

  int filePosition = -1;
  int numberOfThisDisk = 0; // 2 bytes
  int diskWithTheStartOfTheCentralDirectory = 0; // 2 bytes
  int totalCentralDirectoryEntriesOnThisDisk = 0; // 2 bytes
  int totalCentralDirectoryEntries = 0; // 2 bytes
  int centralDirectorySize; // 4 bytes
  int centralDirectoryOffset; // 2 bytes
  String zipFileComment = ''; // 2 bytes, n bytes
  // Central Directory
  List<ZipFileHeader> fileHeaders = [];

  InputStream input;

  CustomZipDirectory([InputStream input]) {
  }

  CustomZipDirectory.readInputStream(this.input);

  read() async {
    filePosition = _findSignature(input);
    input.offset = filePosition;
    int signature = input.readUint32();
    numberOfThisDisk = input.readUint16();
    diskWithTheStartOfTheCentralDirectory = input.readUint16();
    totalCentralDirectoryEntriesOnThisDisk = input.readUint16();
    totalCentralDirectoryEntries = input.readUint16();
    centralDirectorySize = input.readUint32();
    centralDirectoryOffset = input.readUint32();

    int len = input.readUint16();
    if (len > 0) {
      zipFileComment = input.readString(len);
    }

    _readZip64Data(input);

    InputStream dirContent = input.subset(centralDirectoryOffset,
    centralDirectorySize);

    while (!dirContent.isEOS) {
      await new Future.value();
      int fileSig = dirContent.readUint32();
      if (fileSig != ZipFileHeader.SIGNATURE) {
        break;
      }
      fileHeaders.add(new ZipFileHeader(dirContent, input));
    }
  }

  void _readZip64Data(InputStream input) {
    int ip = input.offset;
    // Check for zip64 data.

    // Zip64 end of central directory locator
    // signature                       4 bytes  (0x07064b50)
    // number of the disk with the
    // start of the zip64 end of
    // central directory               4 bytes
    // relative offset of the zip64
    // end of central directory record 8 bytes
    // total number of disks           4 bytes

    int locPos = filePosition - ZIP64_EOCD_LOCATOR_SIZE;
    InputStream zip64 = input.subset(locPos, ZIP64_EOCD_LOCATOR_SIZE);

    int sig = zip64.readUint32();
    // If this ins't the signature we're looking for, nothing more to do.
    if (sig != ZIP64_EOCD_LOCATOR_SIGNATURE) {
      input.offset = ip;
      return;
    }

    int startZip64Disk = zip64.readUint32();
    int zip64DirOffset = zip64.readUint64();
    int numZip64Disks = zip64.readUint32();

    input.offset = zip64DirOffset;

    // Zip64 end of central directory record
    // signature                       4 bytes  (0x06064b50)
    // size of zip64 end of central
    // directory record                8 bytes
    // version made by                 2 bytes
    // version needed to extract       2 bytes
    // number of this disk             4 bytes
    // number of the disk with the
    // start of the central directory  4 bytes
    // total number of entries in the
    // central directory on this disk  8 bytes
    // total number of entries in the
    // central directory               8 bytes
    // size of the central directory   8 bytes
    // offset of start of central
    // directory with respect to
    // the starting disk number        8 bytes
    // zip64 extensible data sector    (variable size)
    sig = input.readUint32();
    if (sig != ZIP64_EOCD_SIGNATURE) {
      input.offset = ip;
      return;
    }

    int zip64EOCDSize = input.readUint64();
    int zip64Version = input.readUint16();
    int zip64VersionNeeded = input.readUint16();
    int zip64DiskNumber = input.readUint32();
    int zip64StartDisk = input.readUint32();
    int zip64NumEntriesOnDisk = input.readUint64();
    int zip64NumEntries = input.readUint64();
    int dirSize = input.readUint64();
    int dirOffset = input.readUint64();

    numberOfThisDisk = zip64DiskNumber;
    diskWithTheStartOfTheCentralDirectory = zip64StartDisk;
    totalCentralDirectoryEntriesOnThisDisk = zip64NumEntriesOnDisk;
    totalCentralDirectoryEntries = zip64NumEntries;
    centralDirectorySize = dirSize;
    centralDirectoryOffset = dirOffset;

    input.offset = ip;
  }

  int _findSignature(InputStream input) {
    int pos = input.offset;
    int length = input.length;

    // The directory and archive contents are written to the end of the zip
    // file.  We need to search from the end to find these structures,
    // starting with the 'End of central directory' record (EOCD).
    for (int ip = length - 4; ip > 0; --ip) {
      input.offset = ip;
      int sig = input.readUint32();
      if (sig == SIGNATURE) {
        input.offset = pos;
        return ip;
      }
    }

    throw new ArchiveException('Could not find End of Central Directory Record');
  }
}
