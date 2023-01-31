#include <iostream>
#include <thread>
#include <cstdlib>
#include <cstring>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
using namespace std;

#include <boost/lockfree/spsc_queue.hpp>

#include <GL/gl.h>
#include <GL/glut.h>
#include <GL/freeglut.h>

constexpr unsigned int MAX_PAYLOAD_LENGTH {1400};
constexpr unsigned int IMAGE_WIDTH  {400};
constexpr unsigned int IMAGE_HEIGHT {300};

struct myRSP_PACKET
{
    uint16_t scene_id; // assume little endian 
    uint16_t row_id;   // assume little endian 
    uint16_t col_id;   // assume little endian 
    uint16_t payload[MAX_PAYLOAD_LENGTH/2]; // RGB565
};

int sock; // UDP socket
// image buffer, write by reconImage, read by drawFunction
// each element should be free at consumer side.
boost::lockfree::spsc_queue<uint8_t*, boost::lockfree::capacity<64>> image_queue; // thread safe FIFO

/* RGB565 -> RGB888 convertion */
uint8_t *rgb565_to_rgb888(uint16_t buf_565) {
    uint8_t *buf = new uint8_t[3];
    buf[0] = (buf_565 & 0xF800) >> 8; // 8-bit R
    buf[1] = (buf_565 & 0x07E0) >> 3; // 8-bit G
    buf[2] = (buf_565 & 0x001F) << 3; // 8-bit B
    return buf;
}

/* gather packets & restore image */
void reconImage () {
    static uint16_t pre_scene_id = 0;
    static uint8_t *bitmap_image = nullptr; // image buffer
    if (!bitmap_image) // if not allocated yed, secure it.
        bitmap_image = new uint8_t[IMAGE_WIDTH * IMAGE_HEIGHT * 3]; // RGB888
              
    /* receive packet */
    struct myRSP_PACKET* packet = new struct myRSP_PACKET; // packet buffer
    auto packet_len  = recv(sock, packet, sizeof(struct myRSP_PACKET), 0);
    auto payload_len = packet_len - 6; // exclude 6 Byte header

    /* if new scene came, write current image buffer to image_queue FIRST. */
    if ((packet->scene_id > pre_scene_id) || (pre_scene_id == 0xFFFF && packet->scene_id == 0x0)) { 
        if (image_queue.write_available()) { // if not full
            uint8_t *copy_image = new uint8_t[IMAGE_WIDTH * IMAGE_HEIGHT * 3];
            memcpy(copy_image, bitmap_image, IMAGE_WIDTH * IMAGE_HEIGHT * 3 * sizeof(uint8_t)); // copy
            image_queue.push(copy_image); // push
        }
        memset(bitmap_image, 0, IMAGE_WIDTH * IMAGE_HEIGHT * 3 * sizeof(uint8_t)); // clear entire image buffer.
        pre_scene_id = packet->scene_id; // update scene id;
        std::cout << "scene: " << packet->scene_id << endl;
    }

    /* check row_id, col_id & assume inside bounding box */
    if (packet->row_id >= IMAGE_HEIGHT) // row-id check
        perror ("packet row_id over IMAGE_HEIGHT, please check settings.\n");
    if (packet->col_id >= IMAGE_WIDTH)  // col-id check
        perror ("packet col_id over IMAGE_WIDTH, please check settings.\n");

    /* don't allow previous lines appear on future image. (UDP don't assume time consistency) */
    if (packet->scene_id == pre_scene_id) {
        unsigned int offset = (packet->row_id * IMAGE_WIDTH * 3) + (packet->col_id * 3); // head pixel offset
        for (int i = 0; i < payload_len/2; ++i) { // payload_len unit on uint8_t, so divide by 2.
            uint8_t *ptr = rgb565_to_rgb888(packet->payload[i]); // RGB565 (uint16_t per pix) -> RGB888 (uint8_t[3] per pix)
            bitmap_image[offset + 3*i]     = ptr[0]; // R
            bitmap_image[offset + 3*i + 1] = ptr[1]; // G
            bitmap_image[offset + 3*i + 2] = ptr[2]; // B
            delete[] ptr;
        }
    } else {
        std::cerr << "[OoO] Out of Order packet detected !!" << std::endl;
    }

    delete packet;
} 

void disp (void) { // read each image from FIFO and render them
    uint8_t* image_ptr;
    static chrono::system_clock::time_point pre_time; // previous time 
    chrono::system_clock::time_point cur_time; // current time

    while (true) {
        if (image_queue.read_available()) { // if not empty (new image data provided), process it
            image_ptr = image_queue.front();
            image_queue.pop(); 
            glClear(GL_COLOR_BUFFER_BIT);
            // render video
            glRasterPos2i(-1, -1);
            glDrawPixels(IMAGE_WIDTH, IMAGE_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, image_ptr);
            // show FPS (Frames per second)
            cur_time = chrono::system_clock::now();
            auto process_period = cur_time - pre_time;
            pre_time = cur_time;
            float fps = 1000.f / chrono::duration_cast<chrono::milliseconds>(process_period).count();
            glRasterPos2f(0.50f, 0.90f);
            char strings[11];
            sprintf(strings, "FPS: %02.3f", (fps));
            glutBitmapString(GLUT_BITMAP_9_BY_15, (const unsigned char*)strings);
            glFlush();
            delete[] image_ptr;
        }
    }
}

int main(int argc, char** argv)
{
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(1234);
    addr.sin_addr.s_addr = INADDR_ANY;
    sock = socket(AF_INET, SOCK_DGRAM, 0);
    bind(sock, (struct sockaddr *)&addr, sizeof(addr));
    
    thread producer_thread( // push image data to image_queue
            [&](void){
            while (true) reconImage();
            });
    thread consumer_thread( // read from image_queue & draw it, then pop-out
            [&](void){
            glutInit(&argc, argv);
            glutInitWindowSize(IMAGE_WIDTH, IMAGE_HEIGHT);
            glutInitDisplayMode(GLUT_SINGLE | GLUT_RGBA | GLUT_DEPTH);

            glutCreateWindow("Broadcasting via UDP socket");
            glutDisplayFunc(disp);
            glutMainLoop();
            });
    
    producer_thread.join();
    consumer_thread.join();

    close(sock);

    return 0;
}
