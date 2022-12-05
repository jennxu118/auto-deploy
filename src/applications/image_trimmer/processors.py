import io
import os
from PIL import Image, ImageChops, UnidentifiedImageError, ImageFile, ImageCms, JpegImagePlugin
from PIL.Image import DecompressionBombError
from datetime import datetime

from rh_dip_core.operators.operator import Operator
from rh_dip_core.logger import LoggerFactory
from rh_dip_core.core import DagRunner
from rh_dip_core.operators.s3 import PutObject, CopyObject


def filter_white_image_background(pixel_value, white_threshold):
    if type(pixel_value) == tuple:
        res = tuple(i >= white_threshold for i in pixel_value)
        return True in res
    else:  # If it is grayscale image, not need trim
        return False


def check_pixel_in_range(pixel_1, pixel_2, pixel_threshold):
    """
    Returns True or False based on if the pixel value for the 2nd pixel is within pixel_1 values +- pixel_threshold.
    Example:
        pixel_1: (205,205,205)
        pixel_2: (203,200,215)
        pixel_threshold: 10 (to be passed in as param, 10 was observed from previous iterations of testing)

        here 203 compared with 205+-10 => 195 <= 203 <= 215 results in True
        code will make elementwise comparison and return tuple of boolean values of same size
        in this case (True, True, True)

        if each element of tuple is True it will return True, if even 1 is False, it will return False

     Args:
        pixel_1: Tuple or int value of 1st pixel
        pixel_2: Tuple or int value of 2nd pixel
        pixel_threshold: The threshold for image comparison. Value as 10 was observed from previous iterations
        of testing
    """
    if type(pixel_1) == tuple:
        # element-wise comparison based on pixel threshold
        res = tuple(i - pixel_threshold <= j <= i + pixel_threshold for i, j in zip(pixel_1, pixel_2))
        # "return 'True' if 'False' is not one of the items list res"
        return True if False not in res else False
    else:
        return pixel_1 - pixel_threshold <= pixel_2 <= pixel_1 + pixel_threshold


def check_and_resize_big_pixel_image(image_original, max_resize_width, max_resize_height):
    """Return a resized image if original image pixels >= 89478485 (the PIL BombWarning limit) else original image
              large_pixel_image flag as True if original image pixels >= 89478485 else False
              The max dimensions allowed for zillow images is 2048 * 1536, use this as reference
    Arg:
        image_original: The original image
        max_resize_width: width of resized image
        max_resize_height: height of resized image
    """
    large_pixel_image = False
    # fetching the dimensions
    width, height = image_original.size
    if width * height >= 89478485:
        large_pixel_image = True
        if width == height:
            max_size = (max_resize_width, max_resize_width)
        elif width > height:
            max_size = (max_resize_width, max_resize_height)
        else:
            max_size = (max_resize_height, max_resize_width)
        # resize image
        return image_original.resize(max_size), large_pixel_image
    else:
        return image_original, large_pixel_image


class ImageTrimmer(Operator):

    def __init__(
        self,
        logger: LoggerFactory,
        dag_runner: DagRunner,
        dag_item_name: str,
        config: dict = None,
        **kwargs
    ):
        super(ImageTrimmer, self).__init__(
            logger = logger,
            dag_runner = dag_runner,
            dag_item_name = dag_item_name
        )
        # Allows pillow to be tolerant of files that are truncated
        ImageFile.LOAD_TRUNCATED_IMAGES = True
        self.INVALID_PIXEL = 999
        self.s3_putObject = PutObject(logger, dag_runner, dag_item_name, config, **kwargs)
        self.s3_copyObject = CopyObject(logger, dag_runner, dag_item_name, config, **kwargs)

    def process(
        self,
        image_s3_object,
        raw_media_payload,
        extensions,
        pixel_threshold,
        white_threshold,
        write_log_debug,
        raw_s3_bucket_name,
        conformed_s3_bucket_name,
        s3_config,
        max_resize_width,
        max_resize_height,
        cropping_offset_value,
        image_save_quality_value
    ):
        raw_media_url = raw_media_payload.get("RawMediaURL")
        conformed_file_path = raw_media_payload.get("MediaURL")
        media_key = raw_media_payload.get("MediaKey")
        media_status = raw_media_payload.get("MediaStatus")
        resource_id = raw_media_payload.get("resource_id")
        source_id = raw_media_payload.get("source_id")

        if raw_media_url is None:
            self.logger.warn(
                message = "Image Trimmer - Missing raw media url ",
                media_key = media_key,
                media_status = media_status,
                resource_id = resource_id
            )
            return {
                "send_to_kafka_dlq": True,
                "kafka_body":        raw_media_payload
            }

        raw_file_path = f"photo/{raw_media_url.split('photo/')[1]}"
        # example of raw_file_path:
        # https://dip-media-raw-files-v1-prod-682179047808.s3.amazonaws.com/photo/S0130/S0130-R0100/82626637/82626637-36.jpg
        # The os.path.splitext() is a built-in Python function that splits the pathname into the pair of root and ext.
        ext = os.path.splitext(raw_file_path)[1]
        start_time = datetime.now()

        # Check if the extension is supported based on list defined above
        # split extensions str into array by delimiter ","
        extensions_array = extensions.split(",")
        # If extension not in list log unsupported extension
        if ext not in extensions_array:
            self.logger.warn(
                message = f"Unsupported extension - {ext} for - {raw_file_path}",
                media_key = media_key,
                media_status = media_status,
                resource_id = resource_id,
                raw_media_url = raw_media_url
            )
            return {
                "send_to_kafka_dlq": True,
                "kafka_body":        raw_media_payload
            }

        # noinspection PyBroadException
        try:
            image_object = image_s3_object.get('Body')
            with Image.open(image_object) as image:
                # initialize boundary_pixels_list since large image will skip trim and not get boundary_pixels_list
                boundary_pixels_list = []
                # check and resize if the image is a large image
                image_after_resize, large_pixel_image = check_and_resize_big_pixel_image(
                    image,
                    max_resize_width,
                    max_resize_height
                )
                # If it is resized large image, don't need to trim
                if large_pixel_image:
                    is_cropped = False
                    cropped = image_after_resize
                    if write_log_debug:
                        self.logger.info(
                            message = "Image is a large pixel image and has been resized.",
                            raw_path = raw_file_path,
                            raw_media_url = raw_media_url,
                            conformed_file_path = conformed_file_path,
                            conformed_bucket = conformed_s3_bucket_name,
                            source_id = source_id,
                            media_key = media_key,
                            media_status = media_status,
                            resource_id = resource_id,
                            action = "Resized",
                            image_width = image.width,
                            image_height = image.height,
                            image_mode = image.mode,
                            image_format = image.format
                        )
                else:
                    is_cropped, cropped, boundary_pixels_list = self.trim(
                        image,
                        pixel_threshold,
                        white_threshold,
                        cropping_offset_value
                    )

                with io.BytesIO() as write_file_stream:
                    # We found image.save reduce the image size, change colorSync profile and sometime reduce dpi too.
                    # We add following parameters to prevent above image changes during image.save
                    # 1. The image quality, on a scale from 1 (worst) to 95 (best). The default is 75
                    # 2. Subsampling: if present, sets the subsampling for the encoder, otherwise will be determined by
                    # libjpeg or libjpeg-turbo
                    # 3. dpi: A tuple of integers representing the pixel density, (x,y).
                    # 4. icc_profile: For colorSync profile
                    #                 If present and true, the image is stored with the provided ICC profile.
                    #                 If this parameter is not provided, image will be saved with no profile attached.
                    if image.info and image.info.get('dpi'):  # Not all image has `image.info`
                        if not image.info.get('icc_profile'):
                            cropped.save(
                                write_file_stream,
                                image.format,
                                quality = image_save_quality_value,
                                subsampling = JpegImagePlugin.get_sampling(image),
                                dpi = image.info.get('dpi')
                            )
                        else:
                            icc = image.info.get('icc_profile')
                            f = io.BytesIO(icc)
                            profile = ImageCms.ImageCmsProfile(f)
                            cropped.save(
                                write_file_stream,
                                image.format,
                                quality = image_save_quality_value,
                                subsampling = JpegImagePlugin.get_sampling(image),
                                dpi = image.info.get('dpi'),
                                icc_profile = profile.tobytes()
                            )

                    else:
                        cropped.save(
                            write_file_stream,
                            image.format,
                            quality = image_save_quality_value,
                            subsampling = JpegImagePlugin.get_sampling(image)
                        )

                    # very important to move pointer back to starting position else nothing will be written
                    write_file_stream.seek(0)
                    # noinspection PyBroadException
                    try:
                        if is_cropped:  # save into media conformed s3
                            self.s3_putObject.process(
                                body = write_file_stream,
                                bucket = conformed_s3_bucket_name,
                                key = conformed_file_path.lstrip("/"),
                                ContentType = 'application/octet-stream'
                            )
                            if write_log_debug:
                                image_size_out = str(write_file_stream.tell())

                                file_process_time_diff = datetime.now() - start_time
                                file_process_milliseconds = \
                                    file_process_time_diff.seconds * 1000 + file_process_time_diff.microseconds / 1000
                                self.logger.info(
                                    message = "Image trimmed.",
                                    raw_path = raw_file_path,
                                    raw_media_url = raw_media_url,
                                    conformed_file_path = conformed_file_path,
                                    conformed_bucket = conformed_s3_bucket_name,
                                    source_id = source_id,
                                    media_key = media_key,
                                    media_status = media_status,
                                    resource_id = resource_id,
                                    action = "Trimmed",
                                    image_width = image.width,
                                    image_height = image.height,
                                    image_mode = image.mode,
                                    image_format = image.format,
                                    image_size_out = image_size_out,
                                    cropped_width = cropped.width,
                                    cropped_height = cropped.height,
                                    cropped_mode = cropped.mode,
                                    processing_time = "{:.3f}".format(file_process_milliseconds),
                                    boundary_pixels_list = boundary_pixels_list,
                                    image_file_extension = ext
                                )
                        else:
                            # Since not all the image will have icc_profile, dpi setup, copy it to media conformed s3
                            # to prevent image changes
                            self.s3_copyObject.process(
                                source_bucket = raw_s3_bucket_name,
                                source_key = raw_file_path,
                                destination_bucket = conformed_s3_bucket_name,
                                destination_key = conformed_file_path.lstrip("/")
                            )
                            if write_log_debug:
                                self.logger.info(
                                    message = "Image trimming is not required.",
                                    raw_path = raw_file_path,
                                    raw_media_url = raw_media_url,
                                    conformed_file_path = conformed_file_path,
                                    conformed_bucket = conformed_s3_bucket_name,
                                    source_id = source_id,
                                    media_key = media_key,
                                    media_status = media_status,
                                    resource_id = resource_id,
                                    action = "Copied",
                                    image_width = image.width,
                                    image_height = image.height,
                                    image_mode = image.mode,
                                    image_format = image.format,
                                    boundary_pixels_list = boundary_pixels_list,
                                    image_file_extension = ext
                                )
                    except Exception:
                        self.logger.error(
                            message = f"Can't Save image to conformed S3. Raw file path - {raw_file_path}.",
                            media_key = media_key,
                            media_status = media_status,
                            ressource_id = resource_id,
                            raw_media_url = raw_media_url
                        )
                        return {
                            "send_to_kafka_dlq": True,
                            "kafka_body":        raw_media_payload
                        }

                # Default. Do not send anything to DLQ if all goes well.
                return {
                    "send_to_kafka_dlq": False,
                    "kafka_body":        {}
                }

        # does not allow corrupted images to be trimmed or copied as is
        except UnidentifiedImageError:
            self.logger.error(
                message = f"Check image for corruption: raw file path - {raw_file_path}",
                media_key = media_key,
                media_status = media_status,
                raw_media_url = raw_media_url,
                resource_id = resource_id
            )
            return {
                "send_to_kafka_dlq": True,
                "kafka_body":        raw_media_payload
            }
        except DecompressionBombError:
            self.logger.error(
                message = f"Image size bigger than 2*89478485 (PIL library default max image size pixels value): "
                          f"raw file path - {raw_file_path}",
                media_key = media_key,
                media_status = media_status,
                raw_media_url = raw_media_url,
                resource_id = resource_id
            )
            return {
                "send_to_kafka_dlq": True,
                "kafka_body":        raw_media_payload
            }
        except Exception:
            self.logger.error(
                message = f"Unexpected error happen: raw file path - {raw_file_path}",
                media_key = media_key,
                media_status = media_status,
                raw_media_url = raw_media_url,
                resource_id = resource_id
            )
            return {
                "send_to_kafka_dlq": True,
                "kafka_body":        raw_media_payload
            }

    def trim(self, image_original, pixel_threshold, white_threshold, cropping_offset_value):
        """
        Returns the original image if no trimming is required, otherwise return the trimmed image false if no trimming
        is required, otherwise return true boundary_pixels_list: contains all 4 corners pixels

        skip_or_pixel, either holds the value of the first pixel or 999 (to skip trimming)
        if it holds pixel value then a background image of the same mode (e.g. RGB) and size (e.g. 1080x720) and color
            of the first pixel is created
        then the difference image (between the original and background) is created
        next, the difference images are added, dividing the result by scale (2.0) and adding the offset(-35)
        We can use an offset value from 0 to -255, 0 is less sensitive and -255 is highly sensitive
        then the bounding_box is calculated, if there is one
        finally, the original image is cropped based on the bounding_box

        Args:
            image_original: The original image
            pixel_threshold: The threshold for image comparison. Value as 10 was observed from previous iterations
            of testing
            white_threshold: The threshold for white border. Value as 240 from elm-media legacy code
            cropping_offset_value: Add offset to the image when adding two images.
        """
        skip_or_pixel, boundary_pixels_list = self.get_optimal_background_pixel(pixel_threshold, image_original)

        if skip_or_pixel != self.INVALID_PIXEL and filter_white_image_background(skip_or_pixel, white_threshold):

            # creates a new background with the same size as the original using the pixel color at 0,0 coordinate
            background = Image.new(image_original.mode, image_original.size, skip_or_pixel)
            # gets the difference between the original image and the background
            difference_image_background = ImageChops.difference(image_original, background)
            # adds the image twice, divides by a scale of 2.0 and adds offset of -35
            difference_image_background = ImageChops.add(
                difference_image_background,
                difference_image_background,
                2.0,
                cropping_offset_value
            )
            # gets the bounding box (4-tuple defining the left, upper, right, and lower pixel coordinate) of the new
            # image
            bounding_box = difference_image_background.getbbox()

            # if bounding_box same as original image then not need trim
            if bounding_box == image_original.getbbox():
                return False, image_original, boundary_pixels_list

            if bounding_box:
                # returns the cropped image based on the calculated bounding_box
                return True, image_original.crop(bounding_box), boundary_pixels_list
        return False, image_original, boundary_pixels_list

    # We only consider white border for now

    def get_optimal_background_pixel(self, pixel_threshold, image_file):
        """
        Returns the optimal value for the pixel to create the background or 999 which equates to skipping the trim logic

        Args:
            image_file: The original image
            pixel_threshold: The threshold for image comparison. Value as 10 was observed from previous iterations of
                testing
        """

        # Image border assumptions:
        # 1. the borders present on the top, bottom, right and left of given image frame (4 edge board)
        # 2. the borders present on the top, bottom or right, left of given image frame (2 edge board)
        # 3. the borders color are same.

        # Scan image frame on pixel level by the threshold from coordinate origin to top-right, bottom-left and
        # bottom-right to see if there are any satisfy above assumptions then set trim flag to true.

        boundary_pixels_list = []
        # top-left pixel
        pixel_0_0 = image_file.getpixel((0, 0))
        boundary_pixels_list.append(pixel_0_0)
        # top-right pixel, width-1 since index starts from 0, so if image is 1080 wide index goes to 1079
        pixel_w_0 = image_file.getpixel((image_file.width - 1, 0))
        boundary_pixels_list.append(pixel_w_0)
        # bottom-left pixel
        pixel_0_h = image_file.getpixel((0, image_file.height - 1))
        boundary_pixels_list.append(pixel_0_h)
        # bottom-right pixel
        pixel_w_h = image_file.getpixel((image_file.width - 1, image_file.height - 1))
        boundary_pixels_list.append(pixel_w_h)

        # check if pixel pairs are in range of the top-left pixel
        # this will only work if we have same color border on all 4 or 2 opposing sides
        if check_pixel_in_range(pixel_0_0, pixel_w_0, pixel_threshold) and \
            check_pixel_in_range(pixel_0_0, pixel_0_h, pixel_threshold) and \
            check_pixel_in_range(pixel_0_0, pixel_w_h, pixel_threshold):
            return pixel_0_0, boundary_pixels_list
        else:
            # pixel range is 0 to 255, so use anything outside that range to skip
            return self.INVALID_PIXEL, boundary_pixels_list
